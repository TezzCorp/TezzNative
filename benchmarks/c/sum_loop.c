#include <stdint.h>

int main(void) {
  const int iters = 2400000;
  int acc = 0;
  for (int i = 0; i < iters; ++i) {
    acc = (acc + (i & 1023)) & 1048575;
  }
  return acc == -1 ? 1 : 0;
}
