from std.testing import assert_equal, assert_raises, assert_true, assert_false, TestSuite

from stoke.deserialize import JsonDeserializable, OptHelp
from stoke.parser import Parser, ParseOptions
from stoke import Stoke


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

def stoke_subcmd_a(var argv: List[String]):
    var args = Parser.parse[Args](argv^)
    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))

def stoke_main(var argv: List[String]):
    var args = Parser.parse[Args](argv^)
    assert_true(args.my_flag)
    assert_equal(args.my_string, "blah")
    assert_equal(args.my_custom, CustomType("John", "Doe"))

def test_stoke_main():
    # N.B. can't use __functions_in_module as that ends up recursively instantiating the test_ fns
    Stoke.register_commands[(stoke_main, stoke_subcmd_a)]([
        "--my-flag",
        "--my-string",
        "blah",
        "--my-custom",
        "John",
        "Doe"
    ]).run()

def test_stoke_subcmd_a():
    # N.B. can't use __functions_in_module as that ends up recursively instantiating the test_ fns
    Stoke.register_commands[(stoke_main, stoke_subcmd_a)]([
        "subcmd-a",
        "--my-flag",
        "--my-string",
        "blah",
        "--my-custom",
        "John",
        "Doe"
    ]).run()

def test_stoke_invalid_subcmd_no_main():
    # With no main, should fail at subcommand matching step
    with assert_raises(contains="No matching command for"):
        Stoke.register_commands[Tuple(stoke_subcmd_a)]([
            "subcmd-b",
            "--my-flag",
            "--my-string",
            "blah",
            "--my-custom",
            "John",
            "Doe"
        ]).run()


def test_stoke_invalid_subcmd_with_main():
    # With a main, it will fall back to trying to parse the main args
    with assert_raises(contains="Can't parse positional argument"):
        Stoke.register_commands[(stoke_main, stoke_subcmd_a)]([
            "subcmd-b",
            "--my-flag",
            "--my-string",
            "blah",
            "--my-custom",
            "John",
            "Doe"
        ]).run()

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()