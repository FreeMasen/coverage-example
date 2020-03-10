pub fn print_hello() {
    println!("Hello, world!");
}

#[cfg(test)]
mod test {
    #[test]
    fn check_printing_no_panic() {
        super::print_hello();
    }
}