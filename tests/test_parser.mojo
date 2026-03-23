from std.testing import (
    assert_equal,
    assert_raises,
    assert_true,
    assert_false,
    TestSuite,
)

from mojopt.default import reflection_default
from mojopt.deserialize import MojOptDeserializable, Opt, get_help
from mojopt.parser import Parser, ParseOptions
from mojopt.error import MojOptErr

from mojopt.ext import *

# TODO: Feature that allows for an argument list to be passed in via a file


@fieldwise_init
struct Args(Defaultable, MojOptDeserializable):
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


fn s(string_literal: StringLiteral) -> StaticString:
    return StaticString(string_literal)


def test_mojopt_basic() raises:
    var parser = Parser(
        [
            s("--my-flag"),
            s("--my-string"),
            s("blah"),
            s("--my-custom"),
            s("John"),
            s("Doe"),
        ]
    )

    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))


def test_mojopt_basic_short_opts() raises:
    var parser = Parser([s("-f"), s("-s"), s("blah"), s("--my-custom"), s("John"), s("Doe")])

    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))


def test_mojopt_flag_default() raises:
    var parser = Parser([s("--my-string"), s("blah"), s("--my-custom"), s("John"), s("Doe")])

    var args = Args.from_opts(parser)

    assert_false(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))


def test_mojopt_mixed_order() raises:
    var parser = Parser(
        [
            s("--my-custom"),
            s("John"),
            s("Doe"),
            s("--my-string"),
            s("blah"),
            s("--my-flag"),
        ]
    )

    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))


def test_mojopt_opt_helper_default() raises:
    var parser = Parser(
        [
            s("--my-custom"),
            s("John"),
            s("Doe"),
            s("--my-flag"),
        ]
    )

    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "FooBar")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))


def test_mojopt_defaultable_default() raises:
    var parser = Parser(
        [
            s("--my-string"),
            s("blah"),
            s("--my-flag"),
        ]
    )

    # Confirm it DOES NOT fall back to using defaultable
    with assert_raises(contains="Missing required option"):
        var _ = Args.from_opts(parser)


def test_mojopt_unexpected_value_after_flag() raises:
    var parser = Parser(
        [
            s("--my-flag"),
            s("balls"),
            s("--my-string"),
            s("blah"),
            s("--my-custom"),
            s("John"),
            s("Doe"),
        ]
    )

    with assert_raises(contains="Can't parse positional argument"):
        var _ = Args.from_opts(parser)


def test_mojopt_unexpected_value_after_opt() raises:
    var parser = Parser(
        [
            s("--my-flag"),
            s("--my-string"),
            s("blah"),
            s("balls"),
            s("--my-custom"),
            s("John"),
            s("Doe"),
        ]
    )

    with assert_raises(contains="Can't parse positional argument"):
        var _ = Args.from_opts(parser)


def test_mojopt_basic_positional_args() raises:
    var parser = Parser(
        [
            s("--my-flag"),
            s("--my-string"),
            s("blah"),
            s("--my-custom"),
            s("John"),
            s("Doe"),
            s("42"),
        ]
    )

    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [42, 43])


def test_mojopt_basic_positional_args_list() raises:
    var parser = Parser(
        [
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
        ]
    )

    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [1, 2, 3])


def test_mojopt_jumbled_positional_args_list() raises:
    var parser = Parser(
        [
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
        ]
    )

    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [1, 2, 3])


def test_mojopt_basic_repeated_opt_list() raises:
    var parser = Parser(
        [
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
        ]
    )

    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [1, 2, 3])
    assert_equal(args.opt_list.value, [5, 6, 7, 8])


def test_mojopt_jumbled_repeated_opt_list() raises:
    var parser = Parser(
        [
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
        ]
    )

    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [1, 2, 3])
    assert_equal(args.opt_list.value, [5, 6, 7, 8])


def test_mojopt_default_repeated_opt_list() raises:
    var parser = Parser(
        [
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
        ]
    )

    var args = Args.from_opts(parser)

    assert_true(args.my_flag.value)
    assert_equal(args.my_string.value, "blah")
    assert_equal(args.my_custom.value, CustomType("John", "Doe"))
    assert_equal(args.arg_one.value, 42)
    assert_equal(args.remaining_args.value, [1, 2, 3])
    assert_equal(args.opt_list.value, [10, 11, 12])


def test_mojopt_default_args_list() raises:
    var parser = Parser(
        [
            s("--my-flag"),
            s("--my-string"),
            s("blah"),
            s("--my-custom"),
            s("John"),
            s("Doe"),
            s("42"),
        ]
    )

    var args = Args.from_opts(parser)

    assert_true(args.my_flag)
    assert_equal("blah", args.my_string)
    assert_equal(CustomType("John", "Doe"), args.my_custom)
    assert_equal(42, args.arg_one)
    assert_equal(
        [42, 43],
        args.remaining_args,
    )
    assert_equal([10, 11, 12], args.opt_list)


@fieldwise_init
struct ArgsBare(Defaultable, MojOptDeserializable):
    var my_int: Int
    var complex: Opt[
        List[String],
        help="This is a complex one",
        long="complex",
        short="c",
        default_value=["cat", "mouse", "dog"],
    ]

    fn __init__(out self):
        self.my_int = Int()
        self.complex = {[]}

    @staticmethod
    fn description() -> String:
        return """Just a simple example program.

        What could possibly go wrong?
        """


def test_bare_args() raises:
    var parser = Parser(
        [
            s("--my-int"),
            s("4"),
            s("--complex"),
            s("snake"),
            s("-c"),
            s("snail"),
            s("--complex"),
            s("cow"),
        ]
    )
    var args = ArgsBare.from_opts(parser)
    assert_equal(args.my_int, 4)
    assert_equal(args.complex.value, ["snake", "snail", "cow"])


# @fieldwise_init
# struct argsunsupported(mojoptdeserializable, defaultable):
#     var my_float: float64
#     var complex: opt[list[string], help="this is a complex one", long="complex", short="c", default="cat,mouse,dog"]

#     fn __init__(out self):
#         self.my_float = float64()
#         self.complex = {[]}

#     @staticmethod
#     fn description() -> string:
#         return """just a simple example program.

#         what could possibly go wrong?
#         """

# def test_unsupported_args() raises:
#     var parser = parser(["--my-int", "4", "--complex", "snake", "-c", "snail", "--complex", "cow"])
#     var args = argsunsupported.from_opts(parser)
#     assert_equal(args.my_float, 4.0)
#     assert_equal(args.complex.value, ["snake", "snail", "cow"])


@fieldwise_init
struct ArgsBareType(Defaultable, MojOptDeserializable):
    var my_num: Int
    var complex: Opt[
        BareComplex,
        help="This is a complex one",
        long="complex",
        short="c",
        default_value=["--animal", "cat", "--thing", "chair", "123"],
    ]
    # Uncomment to get compiler error about multiple List args
    # var many: Opt[List[Int], is_arg=True]

    fn __init__(out self):
        self.my_num = Int()
        self.complex = {BareComplex()}
        # self.many = {[]}

    @staticmethod
    fn description() -> String:
        return """Just a simple example program.

        What could possibly go wrong?
        """


@fieldwise_init
struct BareComplex(Defaultable, ImplicitlyDestructible, Movable):
    var animal: String
    var thing: String
    var many: Opt[List[Int], is_arg=True]

    fn __init__(out self):
        self.animal = "cat"
        self.thing = "chair"
        self.many = {[]}


def test_bare_complex() raises:
    var parser = Parser(
        [
            s("--my-num"),
            s("4"),
            s("--complex"),
            s("--animal"),
            s("dragon"),
            s("--thing"),
            s("table"),
            s("100"),
        ]
    )
    var args = ArgsBareType.from_opts(parser)
    assert_equal(args.my_num, 4)
    assert_equal(args.complex.value.animal, "dragon")
    assert_equal(args.complex.value.thing, "table")


@fieldwise_init
struct DefaultableLarge(Defaultable, ImplicitlyDestructible, MojOptDeserializable):
    var small: Opt[Int, defaultable=True]
    var medium: Opt[List[String], defaultable=True]
    var large: Opt[Thing, defaultable=True]
    var confusing: Opt[String, defaultable=True, default_value=["BrainExplode"]]

    fn __init__(out self):
        self = reflection_default[Self]()


@fieldwise_init
struct Thing(Defaultable, ImplicitlyDestructible, Movable):
    var one: Int
    var name: String

    fn __init__(out self):
        self.one = 1
        self.name = "batman"


def test_defaultable_opts() raises:
    var parser = Parser([])
    var args = DefaultableLarge.from_opts(parser)
    assert_equal(args.small.value, Int())
    assert_equal(args.medium.value, [])
    assert_equal(args.large.value.one, Thing().one)
    assert_equal(args.large.value.name, Thing().name)
    assert_equal(args.confusing.value, "BrainExplode")


@fieldwise_init
struct StringTest(Defaultable, MojOptDeserializable):
    var item: String

    fn __init__(out self):
        self = reflection_default[Self]()


def test_string() raises:
    var parser = Parser(["--item", "foo"])
    var args = StringTest.from_opts(parser)
    assert_equal(args.item, "foo")


@fieldwise_init
struct IntTest(Defaultable, MojOptDeserializable):
    var item: Int

    fn __init__(out self):
        self = reflection_default[Self]()


def test_int() raises:
    var parser = Parser(["--item", "42"])
    var args = IntTest.from_opts(parser)
    assert_equal(args.item, 42)


@fieldwise_init
struct BoolTest(Defaultable, MojOptDeserializable):
    var item: Bool

    fn __init__(out self):
        self = reflection_default[Self]()


def test_bool() raises:
    var parser = Parser(["--item"])
    var args = BoolTest.from_opts(parser)
    assert_true(args.item)


@fieldwise_init
struct FloatTest(Defaultable, MojOptDeserializable):
    var item: Float64

    fn __init__(out self):
        self = reflection_default[Self]()


def test_float() raises:
    var parser = Parser(["--item", "3.14"])
    var args = FloatTest.from_opts(parser)
    assert_equal(args.item, 3.14)


@fieldwise_init
struct IntLiteralTest(Defaultable, MojOptDeserializable):
    comptime Lit = 42
    var item: type_of(Self.Lit)

    fn __init__(out self):
        self = reflection_default[Self]()


def test_int_literal() raises:
    var parser = Parser(["--item", "42"])
    var args = IntLiteralTest.from_opts(parser)
    assert_equal(args.item, 42)


@fieldwise_init
struct FloatLiteralTest(Defaultable, MojOptDeserializable):
    comptime Lit = 42.42
    var item: type_of(Self.Lit)

    fn __init__(out self):
        self = reflection_default[Self]()


def test_float_literal() raises:
    var parser = Parser(["--item", "42.42"])
    var args = FloatLiteralTest.from_opts(parser)
    assert_equal(args.item, 42.42)


from std.memory import ArcPointer


@fieldwise_init
struct ArcPointerTest(Defaultable, MojOptDeserializable):
    var item: ArcPointer[String]

    fn __init__(out self):
        self.item = ArcPointer("foo")


def test_arcpointer() raises:
    var parser = Parser(["--item", "bar"])
    var args = ArcPointerTest.from_opts(parser)
    assert_equal(args.item[], ArcPointer("bar")[])


from std.memory import OwnedPointer


@fieldwise_init
struct OwnedPointerTest(Defaultable, MojOptDeserializable):
    var item: OwnedPointer[String]

    fn __init__(out self):
        self.item = OwnedPointer("foo")


def test_ownedpointer() raises:
    var parser = Parser(["--item", "bar"])
    var args = OwnedPointerTest.from_opts(parser)
    assert_equal(args.item[], OwnedPointer("bar")[])


@fieldwise_init
struct OptionalTest(Defaultable, MojOptDeserializable):
    var item: Optional[String]

    fn __init__(out self):
        self.item = None


def test_optional() raises:
    var parser = Parser(["--item", "bar"])
    var args = OptionalTest.from_opts(parser)
    assert_equal(args.item.value(), "bar")

    var parser_none = Parser([])
    var args_none = OptionalTest.from_opts(parser_none)
    assert_false(args_none.item)


@fieldwise_init
struct ListTest(Defaultable, MojOptDeserializable):
    var item: List[Int]

    fn __init__(out self):
        self.item = []


def test_list() raises:
    var parser = Parser(["--item", "1", "--item", "2", "--item", "3"])
    var args = ListTest.from_opts(parser)
    assert_equal(args.item, [1, 2, 3])


from std.collections import Set


@fieldwise_init
struct SetTest(Defaultable, MojOptDeserializable):
    var item: Set[Int]

    fn __init__(out self):
        self.item = {}


def test_set() raises:
    var parser = Parser(["--item", "1", "--item", "2", "--item", "3", "--item", "3"])
    var args = SetTest.from_opts(parser)
    assert_equal(args.item, {1, 2, 3})


@fieldwise_init
struct InlineArrayTest(Defaultable, MojOptDeserializable):
    var item: Opt[InlineArray[Int, 3], is_arg=True]
    # var item2: InlineArray[Int, 3] # Uncomment to induce compiler error

    fn __init__(out self):
        self.item = {InlineArray[Int, 3](fill=0)}
        # self.item2 = InlineArray[Int, 3](fill=0)


def test_inlinearray() raises:
    var parser = Parser(["1", "2", "3"])
    var args = InlineArrayTest.from_opts(parser)
    assert_equal(args.item.value, [1, 2, 3])


@fieldwise_init
struct TupleTest(Defaultable, MojOptDeserializable):
    var item: Opt[Tuple[Int, String, Float64], is_arg=True]
    # var item2: InlineArray[Int, 3] # Uncomment to induce compiler error

    fn __init__(out self):
        self.item = {Tuple(0, "0", 0.0)}
        # self.item2 = InlineArray[Int, 3](fill=0)


def test_tuple() raises:
    var parser = Parser(["1", "foobar", "3.14"])
    var args = TupleTest.from_opts(parser)
    assert_equal(args.item.value, (1, "foobar", 3.14))


@fieldwise_init
struct NestedTupleTest(Defaultable, MojOptDeserializable):
    var item: Opt[Tuple[Int, String, Tuple[Int, String]], is_arg=True]
    # var item2: InlineArray[Int, 3] # Uncomment to induce compiler error

    fn __init__(out self):
        self.item = {Tuple(0, "0", Tuple(1, "1"))}


def test_nested_tuple() raises:
    var parser = Parser(["1", "foobar", "2", "cats"])
    var args = NestedTupleTest.from_opts(parser)
    assert_equal(args.item.value[0], 1)
    assert_equal(args.item.value[1], "foobar")
    assert_equal(args.item.value[2][0], 2)
    assert_equal(args.item.value[2][1], "cats")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
