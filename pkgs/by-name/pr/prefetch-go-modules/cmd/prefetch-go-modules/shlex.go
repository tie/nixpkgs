package main

import (
	"strings"
)

func shellQuote(s string) string {
	if s == "" {
		return "''"
	}
	quote := strings.ContainsFunc(s, func(r rune) bool {
		return !('a' <= r && r <= 'z' ||
			'A' <= r && r <= 'Z' ||
			'0' <= r && r <= '9' ||
			strings.ContainsRune("/_-+.,", r))
	})
	if !quote {
		return s
	}
	return "'" + strings.ReplaceAll(s, "'", `'"'"'`) + "'"
}
