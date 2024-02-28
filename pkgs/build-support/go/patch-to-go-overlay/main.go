package main

import (
	"encoding/json"
	"errors"
	"flag"
	"strings"
)

var patches = map[string][]string{}

func init() {
	flag.Func(
		"patch",
		"convert module patch to overlay (format: <packagePath>=<patchPath>)",
		func(s string) error {
			modulePath, patchPath, ok := strings.Cut("=")
			if !ok {
				return errors.New("invalid -patch flag argument")
			}
			patches[modulePath] = append(patches[modulePath], patchPath)
			return nil
		},
	)
}

func main() {
}
