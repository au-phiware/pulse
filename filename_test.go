package pulse_test

import (
	"testing"

	"github.com/creativecreature/pulse"
)

type filenameTest struct {
	index    int
	expected string
}

func TestFilename(t *testing.T) {
	testCases := []filenameTest{
		{0, "aaaaaaaaaaaaaaaa.log"},
		{25, "aaaaaaaaaaaaaaaz.log"},
		{26, "aaaaaaaaaaaaaaba.log"},
		{27, "aaaaaaaaaaaaaabb.log"},
		{51, "aaaaaaaaaaaaaabz.log"},
		{52, "aaaaaaaaaaaaaaca.log"},
		{702, "aaaaaaaaaaaaabba.log"},
	}
	for _, tc := range testCases {
		t.Run(tc.expected, func(t *testing.T) {
			actual := pulse.Filename(tc.index)
			if actual != tc.expected {
				t.Errorf("expected %s, got %s", tc.expected, actual)
			}
		})
	}
}

type indexTest struct {
	filename string
	expected int
}

func TestIndex(t *testing.T) {
	testCases := []indexTest{
		{"aaaaaaaaaaaaaaaa.log", 0},
		{"aaaaaaaaaaaaaaaz.log", 25},
		{"aaaaaaaaaaaaaaba.log", 26},
		{"aaaaaaaaaaaaaabb.log", 27},
		{"aaaaaaaaaaaaaabz.log", 51},
		{"aaaaaaaaaaaaaaca.log", 52},
		{"aaaaaaaaaaaaabba.log", 702},
	}

	for _, tc := range testCases {
		t.Run(tc.filename, func(t *testing.T) {
			actual := pulse.Index(tc.filename)
			if actual != tc.expected {
				t.Errorf("expected %d, got %d", tc.expected, actual)
			}
		})
	}
}
