text = b"TezzNative makes native tools readable and fast."
reps = 60_000
acc = 0
for _ in range(reps):
    for j, ch in enumerate(text):
        acc = (acc + ((ch * (j + 1)) & 65_535)) & 1_048_575
if acc == -1:
    raise SystemExit(1)
