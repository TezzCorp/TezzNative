#include <stdint.h>
#include <string.h>

int main(void) {
  const unsigned char *text = (const unsigned char *)"TezzNative makes native tools readable and fast.";
  const int reps = 60000;
  const int n = (int)strlen((const char *)text);
  int acc = 0;
  for (int i = 0; i < reps; ++i) {
    for (int j = 0; j < n; ++j) {
      int ch = (int)text[j];
      acc = (acc + ((ch * (j + 1)) & 65535)) & 1048575;
    }
  }
  return acc == -1 ? 1 : 0;
}
