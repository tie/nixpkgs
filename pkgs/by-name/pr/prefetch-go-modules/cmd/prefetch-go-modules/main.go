package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"
)

// pathsToRemove is a list of GOMODCACHE subpaths that we delete.
//
// Note that we remove sumdb download cache because it can be overriden via
// impureEnvVars by setting GOSUMDB to non-default value (for reference,
// "sum.golang.org+033de0ae+Ac4zctda0e5eza+HJyk9SxEdh+s3Ux18htTTAD8OuAn8 https://sum.golang.org"
// is the default value inferred from "sum.golang.org" sumdb name). We also
// remove VCS cache since it can be non-deterministic.
var pathsToRemove = []string{
	filepath.Join("cache", "lock"),
	filepath.Join("cache", "vcs"),
	filepath.Join("cache", "download", "sumdb"),
}

// goexe allows overriding Go executable at build time via -ldflags-X=... flags.
var goexe = "go"

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

// run is the main entrypoint for the program. It allows using defer and
// standard error handling techniques that require an error return value.
func run() (rerr error) {
	gomodcache := ""
	builder := false

	flag.BoolVar(&builder, "builder", builder, "")
	flag.StringVar(&gomodcache, "gomodcache", gomodcache, "GOMODCACHE")
	flag.Parse()

	modRoots := flag.Args()

	// Create temporary directory if GOMODCACHE path is not set explicitly.
	//
	// Otherwise, ensure that GOMODCACHE directory exists (even if empty).
	if gomodcache == "" {
		tempDir, err := os.MkdirTemp("", "prefetch-go-modules-*")
		if err != nil {
			return err
		}
		gomodcache = tempDir
	} else {
		if err := os.MkdirAll(gomodcache, 0o777); err != nil {
			return err
		}
	}

	if err := downloadModRoots(gomodcache, modRoots); err != nil {
		return err
	}

	for _, p := range pathsToRemove {
		pathToRemove := filepath.Join(gomodcache, p)
		if err := os.RemoveAll(pathToRemove); err != nil {
			return err
		}
	}

	// See https://go.dev/ref/mod#goproxy-protocol
	// File: $base/$module/@v/$version.info
	//
	// When using GOPROXY=direct, info files contain Origin field. We want
	// module cache to be independent of the origin, so remove all unknown
	// fields.
	downloadDir := filepath.Join(gomodcache, "cache", "download")
	err := filepath.WalkDir(
		downloadDir,
		func(path string, d fs.DirEntry, err error) error {
			if path == downloadDir && os.IsNotExist(err) {
				// It’s OK if $GOMODCACHE/cache/download does
				// not exist.
				return nil
			}
			if err != nil {
				return err
			}
			if d.IsDir() || filepath.Ext(path) != ".info" {
				return nil
			}
			return cleanModInfo(path)
		},
	)
	if err != nil {
		return err
	}

	if builder {
		return nil
	}

	sri, err := narHash(gomodcache)
	if err != nil {
		return err
	}
	output := struct {
		Path string
		Hash string
	}{
		Path: gomodcache,
		Hash: sri,
	}
	outputBytes, err := json.MarshalIndent(&output, "", "\t")
	if err != nil {
		return err
	}
	fmt.Printf("%s\n", outputBytes)

	return nil
}

// downloadModRoots runs `go mod download` in each Go module or workspace
// directory with GOMODCACHE set to the given path.
func downloadModRoots(gomodcache string, modRoots []string) error {
	var debug bool
	if n, err := strconv.Atoi(os.Getenv("NIX_DEBUG")); err == nil {
		debug = n > 0
	}
	env := append(os.Environ(),
		"GO111MODULE=on",
		"GOTOOLCHAIN=local",
		"GOMODCACHE="+gomodcache,
	)
	if len(modRoots) == 0 {
		modRoots = []string{""}
	}
	for _, modRoot := range modRoots {
		c := goModDownload(env, debug)
		if modRoot != "" {
			c.Dir = modRoot
		}
		echoCmd("go mod download flags:", c.Args[3:])
		if err := c.Run(); err != nil {
			return err
		}
	}
	return nil
}

// echoCmd prints a command such that all word splits are unambiguous.
func echoCmd(prefix string, args []string) {
	a := make([]any, len(args)+1)
	a[0] = prefix
	for i, s := range args {
		a[i+1] = shellQuote(s)
	}
	fmt.Fprintln(os.Stderr, a...)
}

// goModDownload returns the command invocation for `go mod download` with the
// given environment. It does not run the command.
func goModDownload(env []string, debug bool) *exec.Cmd {
	args := []string{"mod", "download", "-modcacherw"}
	if debug {
		args = append(args, "-x")
	}
	c := exec.Command(goexe, args...)
	c.Stderr = os.Stderr
	c.Env = env
	return c
}

// cleanModInfo removes unknown fields from module info files.
func cleanModInfo(path string) (rerr error) {
	f, err := os.OpenFile(path, os.O_RDWR, 0)
	if err != nil {
		return err
	}
	defer func() {
		if err := f.Close(); err != nil && rerr == nil {
			rerr = err
		}
	}()

	oldContents, err := io.ReadAll(f)
	if err != nil {
		return err
	}

	var info struct {
		Version string    // version string
		Time    time.Time // commit time
	}

	newContents, err := remarshalJSON(oldContents, &info)
	if err != nil {
		return err
	}

	if bytes.Equal(oldContents, newContents) {
		return nil
	}

	if _, err := f.Seek(0, 0); err != nil {
		return err
	}
	if err := f.Truncate(0); err != nil {
		return err
	}

	if _, err := f.Write(newContents); err != nil {
		return err
	}

	return nil
}

// remarshalJSON re-encodes data by unmarshalling it into v and marshaling it
// back to JSON.
func remarshalJSON(data []byte, v any) ([]byte, error) {
	if err := json.Unmarshal(data, v); err != nil {
		return nil, err
	}
	return json.Marshal(v)
}

// narHash returns cryptographic hash of the NAR serialization of a path.
func narHash(path string) (string, error) {
	hash := sha256.New()
	err := narDump(hash, path)
	sri := "sha256-" + base64.StdEncoding.EncodeToString(hash.Sum(nil))
	return sri, err
}
