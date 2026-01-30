package cmd

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/minio/minio-go/v7"
	"github.com/spf13/cobra"

	"github.com/arhuman/s4ync/internal/config"
	"github.com/arhuman/s4ync/internal/parser"
	"github.com/arhuman/s4ync/internal/storage"
)

var listCmd = &cobra.Command{
	Use:   "list",
	Short: "List all projects in the S3 bucket",
	Long:  `List all projects stored in the configured MinIO S3 bucket.`,
	RunE:  runList,
}

func init() {
	rootCmd.AddCommand(listCmd)
}

func runList(_ *cobra.Command, _ []string) error {
	cfg, err := config.LoadFromEnv()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Configuration error: %v\n", err)
		os.Exit(2)
	}

	client, err := storage.NewMinioClient(cfg)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error connecting to S3: %v\n", err)
		os.Exit(1)
	}

	ctx := context.Background()

	type project struct {
		shortname string
		name      string
		gitRepo   string
	}

	var projects []project

	objectCh := client.ListObjects(ctx, cfg.BucketName, minio.ListObjectsOptions{
		Recursive: false,
	})

	for object := range objectCh {
		if object.Err != nil {
			return fmt.Errorf("listing objects: %w", object.Err)
		}

		if !strings.HasSuffix(object.Key, "/") {
			continue
		}

		shortname := strings.TrimSuffix(object.Key, "/")
		p := project{shortname: shortname}

		// Try to read project.md for metadata; skip silently on error.
		obj, err := client.GetObject(ctx, cfg.BucketName, shortname+"/project.md", minio.GetObjectOptions{})
		if err == nil {
			data, readErr := io.ReadAll(obj)
			obj.Close()
			if readErr == nil {
				if fm, parseErr := parser.Parse(data); parseErr == nil {
					p.name = fm.GetString("name")
					p.gitRepo = fm.GetString("git_repo")
				}
			}
		}

		projects = append(projects, p)
	}

	if len(projects) == 0 {
		fmt.Println("No projects found.")
		return nil
	}

	fmt.Printf("%-20s %-30s %s\n", "SHORTNAME", "NAME", "GIT REPO")
	fmt.Println(strings.Repeat("-", 72))
	for _, p := range projects {
		fmt.Printf("%-20s %-30s %s\n", p.shortname, p.name, p.gitRepo)
	}

	return nil
}
