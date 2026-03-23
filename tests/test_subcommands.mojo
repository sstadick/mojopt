from std.testing import (
    assert_equal,
    assert_raises,
    assert_true,
    assert_false,
    TestSuite,
)

from mojopt.default import reflection_default
from mojopt.error import MojOptErr
from mojopt.deserialize import MojOptDeserializable, Opt
from mojopt.parser import Parser, ParseOptions
from mojopt.command import MojOpt, Commandable


@fieldwise_init
struct Args1(Commandable, Defaultable, MojOptDeserializable):
    var my_flag: Opt[Bool, help="It's mine", default_value=["False"], short="f"]
    var my_string: Opt[String, help="Also mine", default_value=["FooBar"], short="s"]
    var my_custom: Opt[CustomType, help="Very custom"]
    var opt_list: Opt[
        List[Int],
        help="Repeatable option",
        default_value=["10", "11", "12"],
        short="l",
    ]
    var arg_one: Opt[Int, help="First positional arg", is_arg=True, default_value=["99"]]
    var remaining_args: Opt[
        List[Int],
        help="Remaining args",
        is_arg=True,
        default_value=["42", "43"],
    ]

    fn __init__(out self):
        self.my_flag = {False}
        self.my_string = {"bar"}
        self.my_custom = {CustomType()}
        self.opt_list = {[]}
        self.arg_one = {1}
        self.remaining_args = {[]}

    @staticmethod
    fn description() -> String:
        return "Command 1 for testing"

    fn run(self) raises:
        assert_true(self.my_flag.value)
        assert_equal(self.my_string.value, "blah")
        assert_equal(self.my_custom.value, CustomType("John", "Doe"))


@fieldwise_init
struct CustomType(Copyable, Defaultable, Equatable, MojOptDeserializable, Writable):
    var first_name: String
    var last_name: String

    fn __init__(out self):
        self.first_name = "Darth"
        self.last_name = "Vadar"

    @implicit
    fn __init__[
        help: String,
        default_value: Optional[List[String]],
        defaultable: Bool,
        long: Optional[String],
        short: Optional[String],
        is_arg: Bool,
    ](out self, opt: Opt[Self, help, default_value, defaultable, long, short, is_arg],):
        self = opt.value.copy()

    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self()
        s.first_name = p.read_string()
        s.last_name = p.read_string()


@fieldwise_init
struct Args2(Commandable, Defaultable, MojOptDeserializable):
    var sport: String
    var position: String
    var placed: Bool

    fn __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    fn description() -> String:
        return "Command 2 for testing"

    fn run(self) raises:
        assert_true(self.placed)
        assert_equal(self.sport, "typing")
        assert_equal(self.position, "homerow")


def test_mojopt_main() raises:
    # N.B. can't use __functions_in_module as that ends up recursively instantiating the test_ fns
    MojOpt[Args1](
        [
            "Args1",
            "--my-flag",
            "--my-string",
            "blah",
            "--my-custom",
            "John",
            "Doe",
        ]
    ).run()

    MojOpt[Args1](["--my-flag", "--my-string", "blah", "--my-custom", "John", "Doe"]).run()


def test_mojopt_arg2() raises:
    MojOpt[Args1, Args2](["Args2", "--placed", "--sport", "typing", "--position", "homerow"]).run()


# This currently exits(2) instead of raising
# def test_mojopt_invalid_subcmd_no_main() raises:
#     # With no main, should fail at subcommand matching step
#     with assert_raises(contains="No matching command for"):
#         MojOpt[Args1, Args2]([
#             "subcmd-b",
#             "--my-flag",
#             "--my-string",
#             "blah",
#             "--my-custom",
#             "John",
#             "Doe"
#         ]).run()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
