# Sync a Cloud Foundry app files with minio


## Prerequesites
* Linux or Mac workstation
* Dotnet Core 2.2 CLI 
* CF Foundation access (equivalent to PAS 2.4 or higher)
  * target Windows cell and org for pushing `app-windows/`
  * target Linux cell and org if you deploy `app-linux/`
* Minio CLI on your workstation
  * Mac
  ```bash
  mkdir bin
  curl -o bin/mc https://dl.minio.io/client/mc/release/darwin-amd64/mc
  chmod +x bin/mc
  bin/mc --help
  ```
  * Linux
  ```bash
  mkdir bin
  curl -o bin/mc https://dl.minio.io/client/mc/release/linux-amd64/mc
  chmod +x bin/mc
  bin/mc --help
  ```


### Note
**No** AWS S3 account is required, this demo will create a private, self-contained Minio S3 connection from your workstation to your app.


# Automated setup
1. Create an `env.sh` file:
   ```bash
   export APP_NAME=<desired CF app name. Ex: "my-app">
   export MINIO_ACCESS_KEY=<any desired password for minio connection>
   export MINIO_SECRET_KEY=<any desired password for minio connection>
   export MINIO_ROUTE_HOSTNAME=<any desired CF hostname to be used for your S3 route. Ex: "my-app-s3">
   export CF_DOMAIN=<existing CF domain to use for your route>
   ```

1. Uncomment relevant `cf push ` command in `up.sh`

1. (app-linux only) Publish your app
   ```bash
   dotnet publish app-linux/
   ```

1. Run `./up.sh` to bring up app in sync-ready state

1. Visit your app page

1. Make a change to your app

1. (app-linux only) Re-publish your app
   ```bash
   dotnet publish app-linux/
   ```

1. Mirror your changes to app instance
   ```bash
   bin/mc mirror <app dir>/ <app name>/app/     #ex: bin/mc mirror app-linux/ my-app/app/
   ```

1. Visit your app page and see it updated
