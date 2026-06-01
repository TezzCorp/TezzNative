#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
  const char *path = "tn_benchmark_file_io.tmp";
  const unsigned char *chunk = (const unsigned char *)"TezzNativeBenchmarkBlock";
  const int chunk_len = (int)strlen((const char *)chunk);
  const int reps = 12000;
  const int expected = chunk_len * reps;
  FILE *out = fopen(path, "wb");
  if (!out) {
    return 1;
  }
  for (int i = 0; i < reps; ++i) {
    if ((int)fwrite(chunk, 1, (size_t)chunk_len, out) != chunk_len) {
      fclose(out);
      remove(path);
      return 2;
    }
  }
  if (fclose(out) != 0) {
    remove(path);
    return 3;
  }

  FILE *in = fopen(path, "rb");
  if (!in) {
    remove(path);
    return 4;
  }
  unsigned char *buf = (unsigned char *)malloc((size_t)chunk_len);
  if (!buf) {
    fclose(in);
    remove(path);
    return 5;
  }
  int total = 0;
  int acc = 0;
  while (total < expected) {
    int got = (int)fread(buf, 1, (size_t)chunk_len, in);
    if (got != chunk_len) {
      free(buf);
      fclose(in);
      remove(path);
      return 6;
    }
    for (int j = 0; j < got; ++j) {
      acc = (acc + (int)buf[j]) & 1048575;
    }
    total += got;
  }
  free(buf);
  fclose(in);
  remove(path);
  return (total == expected && acc != -1) ? 0 : 7;
}
