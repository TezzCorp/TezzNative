const text = Buffer.from("TezzNative makes native tools readable and fast.");
let acc = 0;
for (let i = 0; i < 60000; i += 1) {
  for (let j = 0; j < text.length; j += 1) {
    acc = (acc + ((text[j] * (j + 1)) & 65535)) & 1048575;
  }
}
if (acc === -1) {
  process.exit(1);
}
