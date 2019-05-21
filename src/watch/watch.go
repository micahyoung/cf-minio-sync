package main

import (
	"fmt"
	"os"
	"os/exec"
	"time"
)

type watcher struct {
	watchDir    string
	appURL      string
	s3Port      string
	s3AccessKey string
	s3SecretKey string
}

var (
	minioAppAlias = "watch"
	chiselCmd     *exec.Cmd
	mcMirrorCmd   *exec.Cmd
)

func NewWatcher(watchDir, appURL, s3Port, s3AccessKey, s3SecretKey string) *watcher {
	return &watcher{watchDir, appURL, s3Port, s3AccessKey, s3SecretKey}
}

func (w *watcher) Run() (err error) {
	errs := make(chan error, 1)

	go func() {
		err = w.runChisel()
		if err != nil {
			errs <- err
		}
	}()

	err = w.runMCConfig()
	if err != nil {
		return err
	}

	go func() {
		err = w.runMCMirrorWatch()
		if err != nil {
			errs <- err
		}
	}()

	err = <-errs
	if err != nil {
		return err
	}
	close(errs)

	return err
}

func (w *watcher) runMCMirrorWatch() (err error) {
	mcMirrorCmd = exec.Command("mc", "mirror", "--watch", "--overwrite", "--quiet", w.watchDir, fmt.Sprintf("%s/app", minioAppAlias))
	mcMirrorCmd.Stderr = os.Stderr
	mcMirrorCmd.Stdout = os.Stdout

	fmt.Println("mc watch starting")
	err = mcMirrorCmd.Run()
	if err != nil {
		return err
	}

	return nil
}

func (w *watcher) runMCConfig() (err error) {
	for i := 0; i < 3; i++ {
		var mcConfigCommand *exec.Cmd
		var mcOutput []byte

		fmt.Println("mc config about to run")
		s3URL := fmt.Sprintf("http://127.0.0.1:%s", w.s3Port)
		mcConfigCommand = exec.Command("mc", "config", "host", "add", minioAppAlias, s3URL, w.s3AccessKey, w.s3SecretKey)
		mcOutput, err = mcConfigCommand.CombinedOutput()
		fmt.Printf("mc ran: %s\n", string(mcOutput))

		if err == nil {
			break
		}

		time.Sleep(1 * time.Second)
	}

	return nil
}

func (w *watcher) runChisel() (err error) {
	chiselCmd = exec.Command("chisel", "client", w.appURL, w.s3Port)
	chiselCmd.Stderr = os.Stderr
	chiselCmd.Stdout = os.Stdout

	fmt.Println("chisel starting")
	err = chiselCmd.Run()
	if err != nil {
		return err
	}

	return nil
}

func (w *watcher) Cleanup() {
	if mcMirrorCmd != nil {
		mcMirrorCmd.Process.Kill()
	}
	if mcMirrorCmd != nil {
		mcMirrorCmd.Process.Kill()
	}
	if chiselCmd != nil {
		chiselCmd.Process.Kill()
	}
}
