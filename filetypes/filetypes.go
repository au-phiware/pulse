package filetypes

import (
	"errors"
	"strings"
)

var ErrUnrecognizedFileExtension = errors.New("could not extract a filetype from the filename")

var extensions = map[string]string{
	"go":   "go",
	"js":   "javascript",
	"jsx":  "javascript",
	"ts":   "typescript",
	"tsx":  "typescript",
	"lua":  "lua",
	"md":   "markdown",
	"mdx":  "markdown",
	"css":  "css",
	"less": "css",
	"scss": "css",
	"sh":   "bash",
	"vim":  "vimscript",
	"yml":  "yaml",
	"yaml": "yaml",
	"json": "json",
	"toml": "toml",
}

var specialFiles = map[string]string{
	"Makefile":       "Makefile",
	"Dockerfile":     "Docker",
	"docker-compose": "Docker",
}

// Get tries to extract the filetype from a filename.
func Type(filename string) (string, error) {
	// Start by checking if it is a special file
	file, ok := specialFiles[strings.Split(filename, ".")[0]]
	if ok {
		return file, nil
	}

	// This will return an empty string (zero value) if we don't have a match.
	parts := strings.Split(filename, ".")
	fileExtension := parts[len(parts)-1]
	filetype, ok := extensions[fileExtension]

	if !ok {
		return "", ErrUnrecognizedFileExtension
	}

	return filetype, nil
}