#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

trap 'kill $(jobs -p)' EXIT

source env.sh

APP_ROUTE=$(cf app $APP_NAME | awk '/routes:/ {print $2}')

bin/chisel client http://$APP_ROUTE $MINIO_INTERNAL_PORT &
sleep 1

bin/mc --insecure config host add $APP_NAME http://localhost:$MINIO_INTERNAL_PORT $MINIO_ACCESS_KEY $MINIO_SECRET_KEY

bin/mc watch --recursive $1/ | while read; do bin/mc mirror --overwrite $1/ $APP_NAME/app/; done &

wait
