fn main() {
    let iters: i32 = 2_400_000;
    let mut acc: i32 = 0;
    for i in 0..iters {
        acc = (acc + (i & 1023)) & 1_048_575;
    }
    if acc == -1 {
        std::process::exit(1);
    }
}
