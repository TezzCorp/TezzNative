const fs = require("fs");
const path = "tn_benchmark_file_io.tmp";
const chunk = Buffer.from("TezzNativeBenchmarkBlock");
const reps = 12000;
const expected = chunk.length * reps;

const out = fs.openSync(path, "w");
for (let i = 0; i < reps; i += 1) {
  fs.writeSync(out, chunk);
}
fs.closeSync(out);

if (fs.statSync(path).size !== expected) {
  fs.rmSync(path, { force: true });
  process.exit(1);
}

const input = fs.openSync(path, "r");
const buf = Buffer.alloc(chunk.length);
let total = 0;
let acc = 0;
while (total < expected) {
  const got = fs.readSync(input, buf, 0, chunk.length, null);
  if (got !== chunk.length) {
    fs.closeSync(input);
    fs.rmSync(path, { force: true });
    process.exit(2);
  }
  for (let i = 0; i < got; i += 1) {
    acc = (acc + buf[i]) & 1048575;
  }
  total += got;
}
fs.closeSync(input);
fs.rmSync(path, { force: true });
if (total !== expected || acc === -1) {
  process.exit(3);
}
