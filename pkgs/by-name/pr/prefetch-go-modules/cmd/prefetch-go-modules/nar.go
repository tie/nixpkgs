package main

import (
	"encoding/binary"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
)

const (
	align = 8 // for data alignment

	strHeader     = "\x0d\x00\x00\x00\x00\x00\x00\x00" + "nix-archive-1" + "\x00\x00\x00"
	strLeftParen  = "\x01\x00\x00\x00\x00\x00\x00\x00" + "(" + "\x00\x00\x00\x00\x00\x00\x00"
	strRightParen = "\x01\x00\x00\x00\x00\x00\x00\x00" + ")" + "\x00\x00\x00\x00\x00\x00\x00"
	strType       = "\x04\x00\x00\x00\x00\x00\x00\x00" + "type" + "\x00\x00\x00\x00"
	strRegular    = "\x07\x00\x00\x00\x00\x00\x00\x00" + "regular" + "\x00"
	strExecutable = "\x0a\x00\x00\x00\x00\x00\x00\x00" + "executable" + "\x00\x00\x00\x00\x00\x00"
	strContents   = "\x08\x00\x00\x00\x00\x00\x00\x00" + "contents"
	strSymlink    = "\x07\x00\x00\x00\x00\x00\x00\x00" + "symlink" + "\x00"
	strTarget     = "\x06\x00\x00\x00\x00\x00\x00\x00" + "target" + "\x00\x00"
	strDirectory  = "\x09\x00\x00\x00\x00\x00\x00\x00" + "directory" + "\x00\x00\x00\x00\x00\x00\x00"
	strEntry      = "\x05\x00\x00\x00\x00\x00\x00\x00" + "entry" + "\x00\x00\x00"
	strName       = "\x04\x00\x00\x00\x00\x00\x00\x00" + "name" + "\x00\x00\x00\x00"
	strNode       = "\x04\x00\x00\x00\x00\x00\x00\x00" + "node" + "\x00\x00\x00\x00"
	strEmpty      = "\x00\x00\x00\x00\x00\x00\x00\x00"
)

// narDump writes NAR serialization of a file system path to w.
//
// See https://nixos.org/~eelco/pubs/phd-thesis.pdf, page 93, figure 5.2,
// and https://nix.dev/manual/nix/stable/protocols/nix-archive
func narDump(w io.Writer, path string) error {
	fi, err := os.Lstat(path)
	if err != nil {
		return err
	}
	return serialize(w, path, fs.FileInfoToDirEntry(fi))
}

func serialize(w io.Writer, path string, ent fs.DirEntry) error {
	if _, err := io.WriteString(w, strHeader); err != nil {
		return err
	}
	return serialize1(w, path, ent)
}

func serialize1(w io.Writer, path string, ent fs.DirEntry) error {
	if _, err := io.WriteString(w, strLeftParen); err != nil {
		return err
	}
	if err := serialize2(w, path, ent); err != nil {
		return err
	}
	_, err := io.WriteString(w, strRightParen)
	return err
}

func serialize2(w io.Writer, path string, ent fs.DirEntry) error {
	switch typ := ent.Type(); typ {
	case 0:
		fi, err := ent.Info()
		if err != nil {
			return err
		}
		return serializeRegular(w, path, fi)
	case os.ModeSymlink:
		return serializeSymlink(w, path)
	case os.ModeDir:
		return serializeDirectory(w, path)
	default:
		return fmt.Errorf("invalid file type %s for %q", typ, path)
	}
}

func serializeRegular(w io.Writer, path string, fi fs.FileInfo) (rerr error) {
	if _, err := io.WriteString(w, strType); err != nil {
		return err
	}
	if _, err := io.WriteString(w, strRegular); err != nil {
		return err
	}

	if exec := fi.Mode().Perm()&0o100 != 0; exec {
		if _, err := io.WriteString(w, strExecutable); err != nil {
			return err
		}
		if _, err := io.WriteString(w, strEmpty); err != nil {
			return err
		}
	}
	if _, err := io.WriteString(w, strContents); err != nil {
		return err
	}

	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer func() {
		if err := f.Close(); err != nil && rerr == nil {
			rerr = err
		}
	}()
	return copyFile(w, f, fi.Size())
}

func serializeSymlink(w io.Writer, path string) error {
	if _, err := io.WriteString(w, strType); err != nil {
		return err
	}
	if _, err := io.WriteString(w, strSymlink); err != nil {
		return err
	}
	if _, err := io.WriteString(w, strTarget); err != nil {
		return err
	}
	target, err := os.Readlink(path)
	if err != nil {
		return err
	}
	_, err = w.Write(str(target))
	return err
}

func serializeDirectory(w io.Writer, path string) error {
	if _, err := io.WriteString(w, strType); err != nil {
		return err
	}
	if _, err := io.WriteString(w, strDirectory); err != nil {
		return err
	}
	return writeEntries(w, path)
}

func writeEntries(w io.Writer, path string) error {
	entries, err := os.ReadDir(path)
	if err != nil {
		return err
	}
	for _, ent := range entries {
		entryPath := filepath.Join(path, ent.Name())
		if err := serializeEntry(w, entryPath, ent); err != nil {
			return err
		}
	}
	return nil
}

func serializeEntry(w io.Writer, path string, ent fs.DirEntry) error {
	if _, err := io.WriteString(w, strEntry); err != nil {
		return err
	}
	if _, err := io.WriteString(w, strLeftParen); err != nil {
		return err
	}
	if _, err := io.WriteString(w, strName); err != nil {
		return err
	}
	if _, err := w.Write(str(ent.Name())); err != nil {
		return err
	}
	if _, err := io.WriteString(w, strNode); err != nil {
		return err
	}
	if err := serialize1(w, path, ent); err != nil {
		return err
	}
	_, err := io.WriteString(w, strRightParen)
	return err
}

func copyFile(w io.Writer, r io.Reader, size int64) error {
	var buf [align]byte
	binary.LittleEndian.PutUint64(buf[:], uint64(size))
	if _, err := w.Write(buf[:]); err != nil {
		return err
	}
	rr := &io.LimitedReader{R: r, N: size}
	if _, err := io.Copy(w, rr); err != nil {
		return err
	}
	if rr.N != 0 {
		return io.ErrUnexpectedEOF
	}
	offset := size % align
	if offset == 0 {
		return nil
	}
	_, err := w.Write(make([]byte, align-offset))
	return err
}

func str(s string) []byte {
	buf := make([]byte, strLength(s))
	binary.LittleEndian.PutUint64(buf, uint64(len(s)))
	_ = copy(buf[align:], s)
	return buf
}

func strLength(s string) int64 {
	return paddedLength(align + int64(len(s)))
}

func paddedLength(n int64) int64 {
	return n + (align-n%align)%align
}
