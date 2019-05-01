#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

MINIO_INTERNAL_PORT=9090 # must be wired up to route or used over SSH
PIDFILE="/home/vcap/tmp/start_command.pid"

# current process will become normal start process
echo $$ > $PIDFILE

# read start command from staging_info
start_command="$(jq -r .start_command /home/vcap/staging_info.yml)"

# minio server exposes every directory in $HOME as bucket
/home/vcap/deps/0/bin/minio server --address 0.0.0.0:$MINIO_INTERNAL_PORT /home/vcap &

# mc watch observers changes in $HOME/app and pipes and change...
/home/vcap/deps/0/bin/mc watch --no-color --events put /home/vcap/app/ | while read; do 
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
  echo "Starting command: $start_command"
  bash -c "$start_command" &

  # write pidfile immediately to block further starts
  echo $! > $PIDFILE
  echo "New PID: $(cat $PIDFILE)"
done &
