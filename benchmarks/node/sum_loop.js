let iters = 2400000;
let acc = 0;
for (let i = 0; i < iters; i += 1) {
  acc = (acc + (i & 1023)) & 1048575;
}
if (acc === -1) {
  process.exit(1);
}
