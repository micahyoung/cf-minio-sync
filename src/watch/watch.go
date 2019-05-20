package main

import (
	"fmt"
	"os/exec"
)

type watcher struct {
	watchDir    string
	appName     string
	s3Port      string
	s3AccessKey string
	s3SecretKey string
}

func NewWatcher(watchDir, appName, s3Port, s3AccessKey, s3SecretKey string) *watcher {
	return &watcher{watchDir, appName, s3Port, s3AccessKey, s3SecretKey}
}

func (w *watcher) Run() (err error) {
	var cfAppOutput []byte
	cfAppOutput, err = exec.Command("cf", "app", w.appName).Output()
	fmt.Printf(string(cfAppOutput))
	// }

	// bin/chisel client http://$APP_ROUTE $MINIO_INTERNAL_PORT &
	// sleep 1

	// bin/mc --insecure config host add $APP_NAME http://localhost:$MINIO_INTERNAL_PORT $MINIO_ACCESS_KEY $MINIO_SECRET_KEY

	// bin/mc watch --recursive $1/ | while read; do bin/mc mirror --overwrite $1/ $APP_NAME/app/; done &

	return err
}
