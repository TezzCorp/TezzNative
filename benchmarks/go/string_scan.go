package main

import "os"

func main() {
	text := []byte("TezzNative makes native tools readable and fast.")
	acc := 0
	for i := 0; i < 60000; i++ {
		for j, ch := range text {
			acc = (acc + ((int(ch) * (j + 1)) & 65535)) & 1048575
		}
	}
	if acc == -1 {
		os.Exit(1)
	}
}
