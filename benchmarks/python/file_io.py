from pathlib import Path

path = Path("tn_benchmark_file_io.tmp")
chunk = b"TezzNativeBenchmarkBlock"
reps = 12_000
expected = len(chunk) * reps

with path.open("wb") as f:
    for _ in range(reps):
        f.write(chunk)

if path.stat().st_size != expected:
    path.unlink(missing_ok=True)
    raise SystemExit(1)

total = 0
acc = 0
with path.open("rb") as f:
    while total < expected:
        data = f.read(len(chunk))
        if len(data) != len(chunk):
            path.unlink(missing_ok=True)
            raise SystemExit(2)
        for b in data:
            acc = (acc + b) & 1_048_575
        total += len(data)

path.unlink(missing_ok=True)
if total != expected or acc == -1:
    raise SystemExit(3)
