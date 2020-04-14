use atty::Stream;

pub fn print_hello() {
    if atty::is(Stream::Stdin) {
        println!("Hello, world!");
    } else {
        panic!("must be called from a tty")
    }
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