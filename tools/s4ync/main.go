// Package main is the entry point for the s4ync CLI tool.
package main

import (
	"os"

	"github.com/arhuman/s4ync/cmd"
)

func main() {
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
