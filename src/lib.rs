pub fn print_hello() {
    println!("Hello, world!");
}

pub fn i_am_untested() {
    println!("untested");
}

#[cfg(test)]
mod test {
    #[test]
    fn check_printing_no_panic() {
        super::print_hello();
    }
}