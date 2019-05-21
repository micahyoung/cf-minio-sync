#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

# replace PORT with alternate so chisel listens on 8080 and start command uses 8081
ORIGINAL_APP_PORT=$PORT
ALT_APP_PORT=8081
export PORT=$ALT_APP_PORT

unset ASPNETCORE_URLS

MINIO_INTERNAL_PORT=9090 # must be wired up to route or used over SSH
PIDFILE="/home/vcap/tmp/start_command.pid"

# download chisel
curl --silent --location "https://github.com/jpillora/chisel/releases/download/1.3.1/chisel_linux_amd64.gz" | gzip -d > /home/vcap/deps/chisel
chmod +x /home/vcap/deps/chisel

# download minio server and client
curl --silent --output "/home/vcap/deps/minio" "https://dl.minio.io/server/minio/release/linux-amd64/archive/minio.RELEASE.2019-04-23T23-50-36Z"
curl --silent --output "/home/vcap/deps/mc"    "https://dl.minio.io/client/mc/release/linux-amd64/archive/mc.RELEASE.2019-04-24T00-09-41Z"
chmod +x /home/vcap/deps/minio /home/vcap/deps/mc

# current process will become normal start process
# echo $$ > $PIDFILE

# read start command from staging_info
start_command="$(jq -r .start_command /home/vcap/staging_info.yml)"

# chisel server 
/home/vcap/deps/chisel server --port $ORIGINAL_APP_PORT --proxy "http://127.0.0.1:$ALT_APP_PORT" &

# minio server exposes every directory in $HOME as bucket
/home/vcap/deps/minio server --address 0.0.0.0:$MINIO_INTERNAL_PORT /home/vcap &

# mc watch observers changes in $HOME/app and pipes and change...
/home/vcap/deps/mc watch --no-color --events put /home/vcap/app/ | while read; do 
    # if there's a PID
    #    kill process and clear pid file
    if [ -f $PIDFILE ]; then
        echo "New file added: Killing PID $(cat $PIDFILE)"
        kill $(cat $PIDFILE)
        rm -f $PIDFILE
    else
        echo "New file added: nothing running"
    fi
done &

# endless loop to watch process state and restart
while true; do 
  # if pidfile exists
  if [ -f $PIDFILE ]; then

    # if process not active 
    if ! kill -0 $(cat $PIDFILE); then
        # process died but pidfile wasn't cleared
        # wait for next put to clear the pidfile
        echo "Command exited, waiting to restart until PIDFILE is cleared: \$PIDFILE: \$(cat \$PIDFILE)"
    fi

    # sleep and try loop again in case pidfile has been cleared
    sleep 1
    continue
  fi
  
  # Run start_command in background
  echo "Starting command: $start_command on port $PORT"
  bash -c "$start_command" &

  # write pidfile immediately to block further starts
  echo $! > $PIDFILE
  echo "New PID: $(cat $PIDFILE)"
done
