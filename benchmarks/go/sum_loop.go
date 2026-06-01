package main

import "os"

func main() {
	iters := 2400000
	acc := 0
	for i := 0; i < iters; i++ {
		acc = (acc + (i & 1023)) & 1048575
	}
	if acc == -1 {
		os.Exit(1)
	}
}
