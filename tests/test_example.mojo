
from testing import assert_equal, assert_true, TestSuite

from stoke.deserialize import JsonDeserializable, OptHelp
from stoke.parser import Parser, ParseOptions


# Tests:
# - Missing values (and defaults)
# - Help messages
# - Long and short opts
# - Subcommands

@fieldwise_init
struct Args(JsonDeserializable, Defaultable):
    var my_flag: Bool
    var my_string: String
    var my_custom: CustomType

    fn __init__(out self):
        self.my_flag = False 
        self.my_string = "bar"
        self.my_custom = CustomType()

    @staticmethod
    fn opt_metadata() -> Dict[String, OptHelp]:
        return {
            "my_flag": OptHelp(help_msg="it's mine", default_value="False", short_opt="f")
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

def test_clop_basic():
    var parser = Parser([
        # s("--my-flag"),
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

def test_example():
    assert_equal("🎩", "🎩")

def main():
    TestSuite.discover_tests[__functions_in_module()]().run()
