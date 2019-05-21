package main

import (
	"fmt"
	"os/exec"
	"time"
)

type watcher struct {
	watchDir    string
	appRoute    string
	s3Port      string
	s3AccessKey string
	s3SecretKey string
}

var (
	MINIO_APP_ALIAS = "watch"
)

func NewWatcher(watchDir, appRoute, s3Port, s3AccessKey, s3SecretKey string) *watcher {
	return &watcher{watchDir, appRoute, s3Port, s3AccessKey, s3SecretKey}
}

func (w *watcher) Run() (err error) {
	chiselErrs := make(chan error, 1)

	go func() {
		var chiselCommand *exec.Cmd
		var chiselOutput []byte

		fmt.Println("chisel about to start")
		chiselCommand = exec.Command("chisel", "client", w.appRoute, w.s3Port)
		chiselOutput, err = chiselCommand.CombinedOutput()
		fmt.Println("chisel running")

		if err != nil {
			chiselErrs <- fmt.Errorf(string(chiselOutput), err)

			return
		}

		close(chiselErrs)
	}()

	for i := 0; i < 10; i++ {
		var mcConfigCommand *exec.Cmd
		var mcOutput []byte
		fmt.Println("mc config about to run")
		mcConfigCommand = exec.Command("mc", "--insecure", "config", "host", "add", MINIO_APP_ALIAS, w.appRoute, w.s3AccessKey, w.s3SecretKey)
		mcOutput, err = mcConfigCommand.CombinedOutput()
		fmt.Printf("mc ran: %s\n", string(mcOutput))

		if err == nil {
			break
		}

		time.Sleep(1 * time.Second)
	}

	mcWatchErrs := make(chan error, 1)
	mcWatchOuts := make(chan []byte, 1)

	go func() {
		var mcWatchCommand *exec.Cmd
		var mcWatchOutput []byte

		fmt.Println("mcWatch about to start")
		mcWatchCommand = exec.Command("mc", "watch", "--recursive", MINIO_APP_ALIAS)
		mcWatchOutput, err = mcWatchCommand.Output()
		mcWatchOuts <- mcWatchOutput

		fmt.Println("mcWatch running")

		if err != nil {
			mcWatchErrs <- fmt.Errorf(string(mcWatchOutput), err)

			return
		}

		close(mcWatchErrs)
	}()

	go func() {
		for {
			fmt.Println("mcWatch watching")

			var mcWatchOut []byte
			mcWatchOut = <-mcWatchOuts
			fmt.Print(string(mcWatchOut))
		}
	}()

	// bin/mc watch --recursive $1/ | while read; do bin/mc mirror --overwrite $1/ $APP_NAME/app/; done &

	if err != nil {
		return err
	}

	err = <-chiselErrs
	if err != nil {
		return err
	}

	err = <-mcWatchErrs
	if err != nil {
		return err
	}

	// }

	// bin/chisel client http://$APP_ROUTE $MINIO_INTERNAL_PORT &
	// sleep 1

	// bin/mc --insecure config host add $APP_NAME http://localhost:$MINIO_INTERNAL_PORT $MINIO_ACCESS_KEY $MINIO_SECRET_KEY

	// bin/mc watch --recursive $1/ | while read; do bin/mc mirror --overwrite $1/ $APP_NAME/app/; done &

	return err
}
