from mojopt.deserialize import Opt


__extension String:
    @implicit
    fn __init__[
        help: String,
        default_value: Optional[List[String]],
        defaultable: Bool,
        long: Optional[String],
        short: Optional[String],
        is_arg: Bool,
    ](out self, opt: Opt[String, help, default_value, defaultable, long, short, is_arg],):
        self = opt.value


__extension Int:
    @implicit
    fn __init__[
        help: String,
        default_value: Optional[List[String]],
        defaultable: Bool,
        long: Optional[String],
        short: Optional[String],
        is_arg: Bool,
    ](out self, opt: Opt[Int, help, default_value, defaultable, long, short, is_arg],):
        self = opt.value


__extension Bool:
    @implicit
    fn __init__[
        help: String,
        default_value: Optional[List[String]],
        defaultable: Bool,
        long: Optional[String],
        short: Optional[String],
        is_arg: Bool,
    ](out self, opt: Opt[Bool, help, default_value, defaultable, long, short, is_arg],):
        self = opt.value


__extension List:
    @implicit
    fn __init__[
        T: Copyable,
        help: String,
        default_value: Optional[List[String]],
        defaultable: Bool,
        long: Optional[String],
        short: Optional[String],
        is_arg: Bool,
    ](out self: List[T], opt: Opt[List[T], help, default_value, defaultable, long, short, is_arg],):
        self = opt.value.copy()
