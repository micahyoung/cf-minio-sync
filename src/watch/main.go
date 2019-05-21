package main

import (
	"errors"
	"log"
	"os"

	"github.com/urfave/cli"
)

func main() {
	app := cli.NewApp()

	app.Flags = []cli.Flag{
		cli.StringFlag{
			Name:  "watch-dir, d",
			Usage: "cf app name",
		},
		cli.StringFlag{
			Name:  "app-route, r",
			Usage: "cf app route (ex: my-app.my-domain.com)",
		},
		cli.StringFlag{
			Name:  "s3-port, p",
			Usage: "port for s3 server",
		},
		cli.StringFlag{
			Name:  "s3-access-key",
			Value: "cf-minio-sync",
			Usage: "s3 access key",
		},
		cli.StringFlag{
			Name:  "s3-secret-key",
			Value: "cf-minio-sync",
			Usage: "s3 secret key",
		},
	}

	app.Action = func(c *cli.Context) (err error) {
		watchDir := c.String("watch-dir")
		appRoute := c.String("app-route")
		s3Port := c.String("s3-port")
		s3AccessKey := c.String("s3-access-key")
		s3SecretKey := c.String("s3-secret-key")

		if appRoute == "" || s3Port == "" || s3AccessKey == "" || s3SecretKey == "" {
			return errors.New("add all required fields")
		}

		var watchDirFileInfo os.FileInfo
		if watchDirFileInfo, err = os.Stat(watchDir); os.IsNotExist(err) || !watchDirFileInfo.IsDir() {
			return err
		}

		watcher := NewWatcher(watchDir, appRoute, s3Port, s3AccessKey, s3SecretKey)
		err = watcher.Run()
		if err != nil {
			return err
		}

		return nil
	}

	err := app.Run(os.Args)
	if err != nil {
		log.Fatal(err)
	}
}
