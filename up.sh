#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

source env.sh

MINIO_INTERNAL_PORT=9090

cf delete -f -r $APP_NAME

cat > app/bin/Debug/netcoreapp2.2/publish/live_reload.sh <<EOF
#!/bin/bash

/home/vcap/deps/0/bin/mc watch --no-color --events put /home/vcap/app/ | while read; do kill \$(cat /home/vcap/tmp/start_command.pid); done &
/home/vcap/deps/0/bin/minio server --address 0.0.0.0:$MINIO_INTERNAL_PORT /home/vcap &

start_command="\$(jq -r .start_command /home/vcap/staging_info.yml)"

while sleep 1; do 
  bash -c "\$start_command" &
  echo \$! > /home/vcap/tmp/start_command.pid
  wait
done
EOF

chmod +x app/bin/Debug/netcoreapp2.2/publish/live_reload.sh

cf push $APP_NAME -p app/bin/Debug/netcoreapp2.2/publish/ -b https://github.com/micahyoung/minio-buildpack.git -b dotnet_core_buildpack -k 2GB --no-start -c 'app/live_reload.sh'

cf set-env $APP_NAME MINIO_ACCESS_KEY $MINIO_ACCESS_KEY
cf set-env $APP_NAME MINIO_SECRET_KEY $MINIO_SECRET_KEY

APP_GUID=$(cf app $APP_NAME --guid)
cf curl /v2/apps/$APP_GUID -X PUT -d "{\"ports\":[8080,$MINIO_INTERNAL_PORT]}"

cf start $APP_NAME

CF_SPACE=$(cf target | awk '/space:/ {print $2}')
MINIO_HTTP_ROUTE=$(cf create-route $CF_SPACE $CF_DOMAIN --hostname $MINIO_ROUTE_HOSTNAME | awk '/has been created/ {print $2}')
MINIO_ROUTE_GUID=$(cf curl /v2/routes?q=host:$MINIO_ROUTE_HOSTNAME | jq -r .resources[0].metadata.guid)

cf curl /v2/route_mappings -X POST -d "{\"app_guid\": \"$APP_GUID\", \"route_guid\": \"$MINIO_ROUTE_GUID\", \"app_port\": $MINIO_INTERNAL_PORT}"

cf ssh $APP_NAME -c 'tar -c -C deps/0 mc' | tar -x -C bin

bin/mc --insecure config host add $APP_NAME https://$MINIO_ROUTE_HOSTNAME.$CF_DOMAIN $MINIO_ACCESS_KEY $MINIO_SECRET_KEY