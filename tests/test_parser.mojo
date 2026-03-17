
from std.testing import assert_equal, assert_raises, assert_true, assert_false, TestSuite

from mojopt.deserialize import MojOptDeserializable, Opt, LoadExts, get_help
from mojopt.parser import Parser, ParseOptions
from mojopt.error import MojOptErr

from mojopt.ext import *

# Needed to force the loading of extensions
comptime Exts = LoadExts().FullConformance


# Tests:
# - Missing values (and defaults)
# - Help messages
# - Long and short opts
# - Subcommands

# TODO: help message
# TODO: baked in support for set type opts and args
# TODO: Feature that allows for an argument list to be passed in via a file
# TODO: check if importing a fn makes it in scope for __functions_in_module

@fieldwise_init
struct Args(MojOptDeserializable, Defaultable):
    var my_flag: Opt[Bool, help="It's mine", default="False", short="f"]
    var my_string: Opt[String, help="Also mine", default="FooBar", short="s"]
    var my_custom: Opt[CustomType, help="Very custom"]
    var opt_list: Opt[List[Int], help="Repeatable option", default="10,11,12", short="l"]
    var arg_one: Opt[Int, help="First positional arg", is_arg=True, default="99"]
    var remaining_args: Opt[List[Int], help="Remaining args", is_arg=True, default="42,43"]

    fn __init__(out self):
        self.my_flag = {False}
        self.my_string = {"bar"}
        self.my_custom = {CustomType()}
        self.opt_list = {[]}
        self.arg_one = {1}
        self.remaining_args = {[]}
    

@fieldwise_init
struct CustomType(MojOptDeserializable, Defaultable, Equatable, Writable, Copyable):
    var first_name: String
    var last_name: String

    fn __init__(out self):
        self.first_name = "Darth"
        self.last_name = "Vadar"
    
    @implicit
    fn __init__[
        help: String,
        default: Optional[String],
        long: Optional[String],
        short: Optional[String],
        is_arg: Bool
    ](out self, opt: Opt[Self, help, default, long, short, is_arg]):
        self = opt.value.copy()

    @staticmethod
    fn from_opts[
        options: ParseOptions, //
    ](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self()
        s.first_name = p.read_string()
        s.last_name = p.read_string()


fn s(string_literal: StringLiteral) -> StaticString:
    return StaticString(string_literal)

def test_mojopt_basic() raises :
    var parser = Parser([
        s("--my-flag"),
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe")
    ])
    
    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))

def test_mojopt_basic_short_opts() raises:
    var parser = Parser([
        s("-f"),
        s("-s"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe")
    ])
    
    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))

def test_mojopt_flag_default() raises :
    var parser = Parser([
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe")
    ])
    
    var args = Args.from_opts(parser)

    assert_false(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))

def test_mojopt_mixed_order() raises:
    var parser = Parser([
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("--my-string"),
        s("blah"),
        s("--my-flag"),
    ])
    
    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))

def test_mojopt_opt_helper_default() raises:
    var parser = Parser([
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("--my-flag"),
    ])
    
    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "FooBar")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))

def test_mojopt_defaultable_default() raises:
    var parser = Parser([
        s("--my-string"),
        s("blah"),
        s("--my-flag"),
    ])
    
    # Confirm it DOES NOT fall back to using defaultable
    with assert_raises(contains="Missing required option"):
        var _ = Args.from_opts(parser)

def test_mojopt_unexpected_value_after_flag() raises:
    var parser = Parser([
        s("--my-flag"),
        s("balls"),
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe")
    ])
    

    with assert_raises(contains="Can't parse positional argument"):
        var _ = Args.from_opts(parser)

def test_mojopt_unexpected_value_after_opt() raises:
    var parser = Parser([
        s("--my-flag"),
        s("--my-string"),
        s("blah"),
        s("balls"),
        s("--my-custom"),
        s("John"),
        s("Doe")
    ])
    

    with assert_raises(contains="Can't parse positional argument"):
        var _ = Args.from_opts(parser)

def test_mojopt_basic_positional_args() raises:
    var parser = Parser([
        s("--my-flag"),
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("42")
    ])
    
    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [42, 43])

def test_mojopt_basic_positional_args_list() raises:
    var parser = Parser([
        s("--my-flag"),
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("42"),
        s("1"),
        s("2"),
        s("3"),
    ])
    
    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [1, 2, 3])

def test_mojopt_jumbled_positional_args_list() raises:
    var parser = Parser([
        s("--my-flag"),
        s("42"),
        s("--my-string"),
        s("blah"),
        s("1"),
        s("2"),
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("3"),
    ])
    
    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [1, 2, 3])

def test_mojopt_basic_repeated_opt_list() raises:
    var parser = Parser([
        s("--my-flag"),
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("-l"),
        s("5"),
        s("-l"),
        s("6"),
        s("-l"),
        s("7"),
        s("-l"),
        s("8"),
        s("42"),
        s("1"),
        s("2"),
        s("3"),
    ])
    
    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [1, 2, 3])
    assert_equal(args.opt_list.value, [5, 6, 7, 8])

def test_mojopt_jumbled_repeated_opt_list() raises:
    var parser = Parser([
        s("--my-flag"),
        s("-l"),
        s("5"),
        s("--my-string"),
        s("blah"),
        s("-l"),
        s("6"),
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("-l"),
        s("7"),
        s("42"),
        s("1"),
        s("2"),
        s("3"),
        s("-l"),
        s("8"),
    ])
    
    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [1, 2, 3])
    assert_equal(args.opt_list.value, [5, 6, 7, 8])

def test_mojopt_default_repeated_opt_list() raises:
    var parser = Parser([
        s("--my-flag"),
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("42"),
        s("1"),
        s("2"),
        s("3"),
    ])
    
    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [1, 2, 3])
    assert_equal(args.opt_list.value, [10,11,12])

def test_mojopt_default_args_list() raises:
    var parser = Parser([
        s("--my-flag"),
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("42"),
    ])
    
    var args = Args.from_opts(parser)

    assert_true(args.my_flag)
    assert_equal("blah", args.my_string)
    assert_equal(CustomType("John", "Doe"), args.my_custom)
    assert_equal(42, args.arg_one)
    assert_equal([42, 43], args.remaining_args, )
    assert_equal([10,11,12], args.opt_list)

@fieldwise_init
struct ArgsBare(MojOptDeserializable, Defaultable):
    var my_int: Int
    var complex: Opt[List[String], help="This is a complex one", long="complex", short="c", default="cat,mouse,dog"]

    fn __init__(out self):
        self.my_int = Int()
        self.complex = {[]}

    @staticmethod
    fn description() -> String:
        return """Just a simple example program.

        What could possibly go wrong?
        """
    
def test_bare_args() raises:
    var parser = Parser(["--my-int", "4", "--complex", "snake", "-c", "snail", "--complex", "cow"])
    var args = ArgsBare.from_opts(parser)
    assert_equal(args.my_int, 4)
    assert_equal(args.complex.value, ["snake", "snail", "cow"])

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
