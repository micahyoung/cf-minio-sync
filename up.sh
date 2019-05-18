#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

source env.sh

cf delete -f -r $APP_NAME

# Windows app
# cp profile.bat app-windows/.profile.bat
# cf push $APP_NAME --no-start -p app-windows/ -b hwc_buildpack -s windows -k 2GB -u none

# Linux app
cp profile.sh app-linux/bin/Debug/netcoreapp2.2/publish/.profile
cf push $APP_NAME --no-start -p app-linux/bin/Debug/netcoreapp2.2/publish/ -b dotnet_core_buildpack -k 2GB -u none

cf set-env $APP_NAME MINIO_ACCESS_KEY $MINIO_ACCESS_KEY
cf set-env $APP_NAME MINIO_SECRET_KEY $MINIO_SECRET_KEY

cf start $APP_NAME