
from std.testing import assert_equal, assert_raises, assert_true, assert_false, TestSuite

from stoke.deserialize import JsonDeserializable, OptHelp
from stoke.parser import Parser, ParseOptions


# Tests:
# - Missing values (and defaults)
# - Help messages
# - Long and short opts
# - Subcommands

# TODO: add comptime validation of opt_metadata to check for:
# - collisions of names, especially short opts,
# - verify defaults correctly deserialize,
# - validate keys to make sure they match struct fields
# - make sure there aren't more than one list of positional arguments
# TODO: add comptime check for opt_metadata raises and non-raises

# TODO: help message
# TODO: baked in support for set type opts and args
# TODO: Feature that allows for an argument list to be passed in via a file

@fieldwise_init
struct Args(JsonDeserializable, Defaultable):
    var my_flag: Bool
    var my_string: String
    var my_custom: CustomType
    var opt_list: List[Int]
    var arg_one: Int
    var remaining_args: List[Int]

    fn __init__(out self):
        self.my_flag = False 
        self.my_string = "bar"
        self.my_custom = CustomType()
        self.opt_list = []
        self.arg_one = 1
        self.remaining_args = []

    @staticmethod
    fn opt_metadata() -> Dict[String, OptHelp]:
        return {
            "my_flag": OptHelp(help_msg="it's mine", default_value="False", short_opt="f"),
            "my_string": OptHelp(help_msg="it's also mine", default_value="FooBar", short_opt="s"),
            "opt_list": OptHelp(help_msg="repreated opts", short_opt="l", default_value="10,11,12"),
            "arg_one": OptHelp(help_msg="First argument", is_arg=True, default_value="99"),
            "remaining_args": OptHelp(help_msg="Remaining arguments", is_arg=True, default_value="42,43")
        }
    

@fieldwise_init
struct CustomType(JsonDeserializable, Defaultable, Equatable, Writable):
    var first_name: String
    var last_name: String

    fn __init__(out self):
        self.first_name = "Darth"
        self.last_name = "Vadar"

    @staticmethod
    fn from_json[
        options: ParseOptions, //
    ](mut p: Parser[options], out s: Self) raises:
        # __mlir_op.`lit.ownership.mark_initialized`(__get_mvalue_as_litref(s))
        s = Self()
        s.first_name = p.read_string()
        s.last_name = p.read_string()

    @staticmethod
    fn opt_metadata() -> Dict[String, OptHelp]:
        return {}

fn s(string_literal: StringLiteral) -> StaticString:
    return StaticString(string_literal)

def test_stoke_basic():
    var parser = Parser([
        s("--my-flag"),
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe")
    ])
    
    var args = Args.from_json(parser)

    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))

def test_stoke_basic_short_opts():
    var parser = Parser([
        s("-f"),
        s("-s"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe")
    ])
    
    var args = Args.from_json(parser)

    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))

def test_stoke_flag_default():
    var parser = Parser([
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe")
    ])
    
    var args = Args.from_json(parser)

    assert_false(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))

def test_stoke_mixed_order():
    var parser = Parser([
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("--my-string"),
        s("blah"),
        s("--my-flag"),
    ])
    
    var args = Args.from_json(parser)

    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))

def test_stoke_opt_helper_default():
    var parser = Parser([
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("--my-flag"),
    ])
    
    var args = Args.from_json(parser)

    assert_true(args.my_flag)
    assert_equal(args.my_string, "FooBar")
    assert_equal(args.my_custom, CustomType("John", "Doe"))

def test_stoke_defaultable_default():
    var parser = Parser([
        s("--my-string"),
        s("blah"),
        s("--my-flag"),
    ])
    
    # Confirm it DOES NOT fall back to using defaultable
    with assert_raises(contains="Missing key"):
        var args = Args.from_json(parser)

def test_stoke_unexpected_value_after_flag():
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
        var args = Args.from_json(parser)

def test_stoke_unexpected_value_after_opt():
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
        var args = Args.from_json(parser)

def test_stoke_basic_positional_args():
    var parser = Parser([
        s("--my-flag"),
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("42")
    ])
    
    var args = Args.from_json(parser)

    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))
    assert_equal(args.arg_one, 42)
    assert_equal(args.remaining_args, [42, 43])

def test_stoke_basic_positional_args_list():
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
    
    var args = Args.from_json(parser)

    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))
    assert_equal(args.arg_one, 42)
    assert_equal(args.remaining_args, [1, 2, 3])

def test_stoke_jumbled_positional_args_list():
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
    
    var args = Args.from_json(parser)

    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))
    assert_equal(args.arg_one, 42)
    assert_equal(args.remaining_args, [1, 2, 3])

def test_stoke_basic_repeated_opt_list():
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
    
    var args = Args.from_json(parser)

    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))
    assert_equal(args.arg_one, 42)
    assert_equal(args.remaining_args, [1, 2, 3])
    assert_equal(args.opt_list, [5, 6, 7, 8])

def test_stoke_jumbled_repeated_opt_list():
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
    
    var args = Args.from_json(parser)

    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))
    assert_equal(args.arg_one, 42)
    assert_equal(args.remaining_args, [1, 2, 3])
    assert_equal(args.opt_list, [5, 6, 7, 8])

def test_stoke_default_repeated_opt_list():
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
    
    var args = Args.from_json(parser)

    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))
    assert_equal(args.arg_one, 42)
    assert_equal(args.remaining_args, [1, 2, 3])
    assert_equal(args.opt_list, [10,11,12])

def test_stoke_default_args_list():
    var parser = Parser([
        s("--my-flag"),
        s("--my-string"),
        s("blah"),
        s("--my-custom"),
        s("John"),
        s("Doe"),
        s("42"),
    ])
    
    var args = Args.from_json(parser)

    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))
    assert_equal(args.arg_one, 42)
    assert_equal(args.remaining_args, [42, 43])
    assert_equal(args.opt_list, [10,11,12])

def main():
    TestSuite.discover_tests[__functions_in_module()]().run()
