fn main() {
    let text = b"TezzNative makes native tools readable and fast.";
    let mut acc: i32 = 0;
    for _ in 0..60_000 {
        for (j, ch) in text.iter().enumerate() {
            acc = (acc + (((*ch as i32) * ((j as i32) + 1)) & 65_535)) & 1_048_575;
        }
    }
    if acc == -1 {
        std::process::exit(1);
    }
}
