#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

source env.sh

MINIO_INTERNAL_PORT=9090

cf delete -f -r $APP_NAME

cp profile.sh app/bin/Debug/netcoreapp2.2/publish/.profile

cf push $APP_NAME --no-start -p app/bin/Debug/netcoreapp2.2/publish/ -b https://github.com/micahyoung/minio-buildpack.git -b dotnet_core_buildpack -u none -k 2GB

cf set-env $APP_NAME MINIO_ACCESS_KEY $MINIO_ACCESS_KEY
cf set-env $APP_NAME MINIO_SECRET_KEY $MINIO_SECRET_KEY

APP_GUID=$(cf app $APP_NAME --guid)
cf curl /v2/apps/$APP_GUID -X PUT -d "{\"ports\":[8080,$MINIO_INTERNAL_PORT]}"

cf start $APP_NAME

CF_SPACE=$(cf target | awk '/space:/ {print $2}')
MINIO_HTTP_ROUTE=$(cf create-route $CF_SPACE $CF_DOMAIN --hostname $MINIO_ROUTE_HOSTNAME | awk '/has been created/ {print $2}')
MINIO_ROUTE_GUID=$(cf curl /v2/routes?q=host:$MINIO_ROUTE_HOSTNAME | jq -r .resources[0].metadata.guid)

cf curl /v2/route_mappings -X POST -d "{\"app_guid\": \"$APP_GUID\", \"route_guid\": \"$MINIO_ROUTE_GUID\", \"app_port\": $MINIO_INTERNAL_PORT}"

cf ssh $APP_NAME -c 'gzip --stdout /home/vcap/deps/0/bin/mc' | gzip --decompress > bin/mc

bin/mc --insecure config host add $APP_NAME https://$MINIO_ROUTE_HOSTNAME.$CF_DOMAIN $MINIO_ACCESS_KEY $MINIO_SECRET_KEY