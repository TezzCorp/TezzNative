iters = 2_400_000
i = 0
acc = 0
while i < iters:
    acc = (acc + (i & 1023)) & 1_048_575
    i += 1
if acc == -1:
    raise SystemExit(1)
