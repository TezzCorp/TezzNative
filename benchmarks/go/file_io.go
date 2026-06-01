package main

import (
	"bytes"
	"os"
)

func main() {
	path := "tn_benchmark_file_io.tmp"
	chunk := []byte("TezzNativeBenchmarkBlock")
	reps := 12000
	expected := len(chunk) * reps

	out, err := os.Create(path)
	if err != nil {
		os.Exit(1)
	}
	for i := 0; i < reps; i++ {
		if n, err := out.Write(chunk); err != nil || n != len(chunk) {
			out.Close()
			os.Remove(path)
			os.Exit(2)
		}
	}
	if out.Close() != nil {
		os.Remove(path)
		os.Exit(3)
	}
	info, err := os.Stat(path)
	if err != nil || int(info.Size()) != expected {
		os.Remove(path)
		os.Exit(4)
	}

	data, err := os.ReadFile(path)
	os.Remove(path)
	if err != nil || len(data) != expected || !bytes.Equal(data[:len(chunk)], chunk) {
		os.Exit(5)
	}
	acc := 0
	for _, b := range data {
		acc = (acc + int(b)) & 1048575
	}
	if acc == -1 {
		os.Exit(6)
	}
}
