use std::fs;
use std::io::{Read, Write};

fn main() {
    let path = "tn_benchmark_file_io.tmp";
    let chunk = b"TezzNativeBenchmarkBlock";
    let reps = 12_000usize;
    let expected = chunk.len() * reps;

    let mut out = fs::File::create(path).unwrap_or_else(|_| std::process::exit(1));
    for _ in 0..reps {
        if out.write_all(chunk).is_err() {
            let _ = fs::remove_file(path);
            std::process::exit(2);
        }
    }
    drop(out);

    let mut input = fs::File::open(path).unwrap_or_else(|_| {
        let _ = fs::remove_file(path);
        std::process::exit(3);
    });
    let mut data = Vec::new();
    if input.read_to_end(&mut data).is_err() {
        let _ = fs::remove_file(path);
        std::process::exit(4);
    }
    let _ = fs::remove_file(path);
    if data.len() != expected {
        std::process::exit(5);
    }
    let mut acc: i32 = 0;
    for b in data {
        acc = (acc + (b as i32)) & 1_048_575;
    }
    if acc == -1 {
        std::process::exit(6);
    }
}
