powershell -Command $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -OutFile "c:\Users\vcap\deps\minio.exe" "https://dl.minio.io/server/minio/release/windows-amd64/archive/minio.RELEASE.2019-04-23T23-50-36Z"

START /B c:\Users\vcap\deps\minio.exe server --address 0.0.0.0:9090 c:\Users\vcap