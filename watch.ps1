param (
    [Parameter(Mandatory=$true)]
    [string]$watchDir 
)
$ErrorActionPreference="Stop"

# trap clean up child processes

. .\env.ps1

$watchDirFullPath=(Resolve-Path $watchDir)
$env:APP_ROUTE=(cf app $env:APP_NAME | findstr "routes:" | %{ [regex]::split($_, ' +')[1]; })

Start-Job -Name chisel {& "$args\bin\chisel.exe" client http://$env:APP_ROUTE $env:MINIO_INTERNAL_PORT } -ArgumentList $PWD
Wait-Job -Any -Name chisel
Start-Sleep 1
exit 1

bin/mc --insecure config host add $env:APP_NAME http://127.0.0.1:$env:MINIO_INTERNAL_PORT $env:MINIO_ACCESS_KEY $env:MINIO_SECRET_KEY

Start-Job -Name mc { & { ".\bin\mc watch --recursive $watchDir/ | %{ bin/mc mirror --overwrite $watchDirFullPath/ $APP_NAME/app/ }" } }

Wait-Job -Any -Name chisel,mc
