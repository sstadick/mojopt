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
from mojopt.error import MojOptErr, DisplayHelp

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

    def __init__(out self):
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

    def __init__(out self):
        self.first_name = "Darth"
        self.last_name = "Vadar"

    @implicit
    def __init__[
        default_value_length: Int,
        //,
        help: String,
        default_value: Optional[Array[String, default_value_length]],
        defaultable: Bool,
        long: Optional[String],
        short: Optional[String],
        is_arg: Bool,
    ](
        out self,
        opt: Opt[
            default_value_length=default_value_length,
            T=Self,
            help=help,
            default_value=default_value,
            defaultable=defaultable,
            long=long,
            short=short,
            is_arg=is_arg,
        ],
    ):
        self = opt.value.copy()

    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self()
        s.first_name = p.read_string()
        s.last_name = p.read_string()


def s(string_literal: StringLiteral) -> StaticString:
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
        List([42, 43]),
        args.remaining_args,
    )
    assert_equal(List([10, 11, 12]), args.opt_list)


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

    def __init__(out self):
        self.my_int = Int()
        self.complex = {[]}

    @staticmethod
    def description() -> String:
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

    def __init__(out self):
        self.my_num = Int()
        self.complex = {BareComplex()}
        # self.many = {[]}

    @staticmethod
    def description() -> String:
        return """Just a simple example program.

        What could possibly go wrong?
        """


@fieldwise_init
struct BareComplex(Defaultable, Deinitable, Movable):
    var animal: String
    var thing: String
    var many: Opt[List[Int], is_arg=True]

    def __init__(out self):
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
struct DefaultableLarge(Defaultable, Deinitable, MojOptDeserializable):
    var small: Opt[Int, defaultable=True]
    var medium: Opt[List[String], defaultable=True]
    var large: Opt[Thing, defaultable=True]
    var confusing: Opt[String, defaultable=True, default_value=["BrainExplode"]]

    def __init__(out self):
        self = reflection_default[Self]()


@fieldwise_init
struct Thing(Defaultable, Deinitable, Movable):
    var one: Int
    var name: String

    def __init__(out self):
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

    def __init__(out self):
        self = reflection_default[Self]()


def test_string() raises:
    var parser = Parser(["--item", "foo"])
    var args = StringTest.from_opts(parser)
    assert_equal(args.item, "foo")


@fieldwise_init
struct IntTest(Defaultable, MojOptDeserializable):
    var item: Int

    def __init__(out self):
        self = reflection_default[Self]()


def test_int() raises:
    var parser = Parser(["--item", "42"])
    var args = IntTest.from_opts(parser)
    assert_equal(args.item, 42)


@fieldwise_init
struct BoolTest(Defaultable, MojOptDeserializable):
    var item: Bool

    def __init__(out self):
        self = reflection_default[Self]()


def test_bool() raises:
    var parser = Parser(["--item"])
    var args = BoolTest.from_opts(parser)
    assert_true(args.item)


@fieldwise_init
struct FloatTest(Defaultable, MojOptDeserializable):
    var item: Float64

    def __init__(out self):
        self = reflection_default[Self]()


def test_float() raises:
    var parser = Parser(["--item", "3.14"])
    var args = FloatTest.from_opts(parser)
    assert_equal(args.item, 3.14)


@fieldwise_init
struct IntLiteralTest(Defaultable, MojOptDeserializable):
    comptime Lit = 42
    var item: type_of(Self.Lit)

    def __init__(out self):
        self = reflection_default[Self]()


def test_int_literal() raises:
    var parser = Parser(["--item", "42"])
    var args = IntLiteralTest.from_opts(parser)
    assert_equal(args.item, 42)


@fieldwise_init
struct FloatLiteralTest(Defaultable, MojOptDeserializable):
    comptime Lit = 42.42
    var item: type_of(Self.Lit)

    def __init__(out self):
        self = reflection_default[Self]()


def test_float_literal() raises:
    var parser = Parser(["--item", "42.42"])
    var args = FloatLiteralTest.from_opts(parser)
    assert_equal(args.item, 42.42)


from std.memory import ArcPointer


@fieldwise_init
struct ArcPointerTest(Defaultable, MojOptDeserializable):
    var item: ArcPointer[String]

    def __init__(out self):
        self.item = ArcPointer("foo")


def test_arcpointer() raises:
    var parser = Parser(["--item", "bar"])
    var args = ArcPointerTest.from_opts(parser)
    assert_equal(args.item[], ArcPointer("bar")[])


from std.memory import OwnedPointer


@fieldwise_init
struct OwnedPointerTest(Defaultable, MojOptDeserializable):
    var item: OwnedPointer[String]

    def __init__(out self):
        self.item = OwnedPointer("foo")


def test_ownedpointer() raises:
    var parser = Parser(["--item", "bar"])
    var args = OwnedPointerTest.from_opts(parser)
    assert_equal(args.item[], OwnedPointer("bar")[])


@fieldwise_init
struct OptionalTest(Defaultable, MojOptDeserializable):
    var item: Optional[String]

    def __init__(out self):
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

    def __init__(out self):
        self.item = []


def test_list() raises:
    var parser = Parser(["--item", "1", "--item", "2", "--item", "3"])
    var args = ListTest.from_opts(parser)
    assert_equal(args.item, [1, 2, 3])


def test_list_parse_error() raises:
    var parser = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingArguments)](["1", "bad"])
    with assert_raises():
        var _ = List[Int].from_opts(parser)


from std.collections import Set


@fieldwise_init
struct SetTest(Defaultable, MojOptDeserializable):
    var item: Set[Int]

    def __init__(out self):
        self.item = {}


def test_set() raises:
    var parser = Parser(["--item", "1", "--item", "2", "--item", "3", "--item", "3"])
    var args = SetTest.from_opts(parser)
    assert_equal(args.item, {1, 2, 3})


def test_set_parse_error() raises:
    var parser = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingArguments)](["1", "bad"])
    with assert_raises():
        var _ = Set[Int].from_opts(parser)


@fieldwise_init
struct ArrayTest(Defaultable, MojOptDeserializable):
    var item: Opt[Array[Int, 3], is_arg=True]
    # var item2: Array[Int, 3] # Uncomment to induce compiler error

    def __init__(out self):
        self.item = {Array[Int, 3](fill=0)}
        # self.item2 = Array[Int, 3](fill=0)


def test_array() raises:
    var parser = Parser(["1", "2", "3"])
    var args = ArrayTest.from_opts(parser)
    assert_equal(args.item.value, [1, 2, 3])


def test_array_parse_error() raises:
    var invalid = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingArguments)](
        ["1", "bad", "3"]
    )
    with assert_raises():
        var _ = Array[Int, 3].from_opts(invalid)

    var too_short = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingArguments)](["1", "2"])
    with assert_raises():
        var _ = Array[Int, 3].from_opts(too_short)


@fieldwise_init
struct TupleTest(Defaultable, MojOptDeserializable):
    var item: Opt[Tuple[Int, String, Float64], is_arg=True]
    # var item2: Array[Int, 3] # Uncomment to induce compiler error

    def __init__(out self):
        self.item = {Tuple(0, "0", 0.0)}
        # self.item2 = Array[Int, 3](fill=0)


def test_tuple() raises:
    var parser = Parser(["1", "foobar", "3.14"])
    var args = TupleTest.from_opts(parser)
    assert_equal(args.item.value, (1, "foobar", 3.14))


def test_tuple_parse_error() raises:
    var invalid = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingArguments)](
        ["1", "foobar", "bad"]
    )
    with assert_raises():
        var _ = Tuple[Int, String, Float64].from_opts(invalid)

    var too_short = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingArguments)](
        ["1", "foobar"]
    )
    with assert_raises():
        var _ = Tuple[Int, String, Float64].from_opts(too_short)


@fieldwise_init
struct NestedTupleTest(Defaultable, MojOptDeserializable):
    var item: Opt[Tuple[Int, String, Tuple[Int, String]], is_arg=True]
    # var item2: Array[Int, 3] # Uncomment to induce compiler error

    def __init__(out self):
        self.item = {Tuple(0, "0", Tuple(1, "1"))}


def test_nested_tuple() raises:
    var parser = Parser(["1", "foobar", "2", "cats"])
    var args = NestedTupleTest.from_opts(parser)
    assert_equal(args.item.value[0], 1)
    assert_equal(args.item.value[1], "foobar")
    assert_equal(args.item.value[2][0], 2)
    assert_equal(args.item.value[2][1], "cats")


__enum Mode(ImplicitlyCopyable):
    case fast
    case Careful
    case dry_run


@fieldwise_init
struct ChoiceArgs(Defaultable, MojOptDeserializable):
    var mode: Opt[Mode, short="m", default_value=["Careful"]]
    var modes: Opt[List[Mode], short="M", default_value=["fast", "dry_run"]]

    def __init__(out self):
        self.mode = {Mode.fast}
        self.modes = {[]}


def test_enum_choices() raises:
    var args = Parser.parse[ChoiceArgs](["--mode=dry_run", "-Mfast", "--modes=Careful", "-Mfast"])
    assert_equal(args.mode.value._get_enum_discriminant(), 2)
    assert_true(args.mode.provided)
    assert_equal(len(args.modes.value), 3)
    assert_equal(args.modes.value[0]._get_enum_discriminant(), 0)
    assert_equal(args.modes.value[1]._get_enum_discriminant(), 1)
    assert_equal(args.modes.value[2]._get_enum_discriminant(), 0)
    var defaults = Parser.parse[ChoiceArgs]([])
    assert_equal(defaults.mode.value._get_enum_discriminant(), 1)
    assert_false(defaults.mode.provided)
    assert_false(defaults.modes.provided)
    for invalid in ["careful", "FAST", "dry-run", "", "unknown"]:
        with assert_raises(contains="Expected one of [fast, Careful, dry_run]"):
            var _ = Parser.parse[ChoiceArgs]([String("--mode=", invalid)])
    var help = get_help[ChoiceArgs]()
    assert_true("[choices: fast, Careful, dry_run]" in help)
    assert_true("--modes=MODES..." in help)


@fieldwise_init
struct Forms(Defaultable, MojOptDeserializable):
    var verbose: Opt[Bool, short="v", default_value=["true"]]
    var quiet: Opt[Bool, short="q", defaultable=True]
    var name: Opt[String, short="n", default_value=["default"]]
    var count: Opt[Int, short="c", default_value=["7"]]
    var include: Opt[List[String], short="I", default_value=["default-path"]]
    var unique: Opt[Set[Int], short="u", default_value=["8"]]
    var files: Opt[List[String], is_arg=True, default_value=["default-file"]]

    def __init__(out self):
        self.verbose = {False}
        self.quiet = {False}
        self.name = {""}
        self.count = {0}
        self.include = {["stale"]}
        self.unique = {{99}}
        self.files = {[]}
        self.name.provided = True
        self.count.provided = True
        self.verbose.provided = True
        self.files.provided = True


def test_long_equals_and_presence() raises:
    var args = Parser.parse[Forms](["--name=a=b", "--count=-23", "--verbose=false"])
    assert_equal(args.name.value, "a=b")
    assert_equal(args.count.value, -23)
    assert_false(args.verbose.value)
    assert_true(args.name.provided)
    assert_true(args.count.provided)
    assert_true(args.verbose.provided)
    assert_false(args.quiet.provided)
    assert_false(args.include.provided)
    assert_false(args.files.provided)
    var empty = Parser.parse[Forms](["--name=", "--count=0", "--verbose=false"])
    assert_equal(empty.name.value, "")
    assert_equal(empty.count.value, 0)
    assert_true(empty.name.provided)
    assert_true(empty.count.provided)
    assert_true(empty.verbose.provided)
    var defaults = Parser.parse[Forms]([])
    assert_equal(defaults.name.value, "default")
    assert_equal(defaults.count.value, 7)
    assert_true(defaults.verbose.value)
    assert_false(defaults.name.provided)
    assert_false(defaults.count.provided)
    assert_false(defaults.verbose.provided)
    assert_false(defaults.files.provided)
    var explicit_defaults = Parser.parse[Forms](["--name=default", "--count=7", "default-file"])
    assert_true(explicit_defaults.name.provided)
    assert_true(explicit_defaults.count.provided)
    assert_true(explicit_defaults.files.provided)


def test_short_bundles_and_attached_values() raises:
    var args = Parser.parse[Forms](["-qvvc-6", "-nAda Lovelace", "-I=literal"])
    assert_true(args.verbose.value)
    assert_true(args.quiet.value)
    assert_equal(args.count.value, -6)
    assert_equal(args.name.value, "Ada Lovelace")
    assert_equal(args.include.value, ["=literal"])
    var separated = Parser.parse[Forms](["-vqc", "19", "-n", "", "-I", "--help"])
    assert_true(separated.quiet.value)
    assert_equal(separated.count.value, 19)
    assert_equal(separated.name.value, "")
    assert_equal(separated.include.value, ["--help"])
    assert_true(separated.name.provided)
    with assert_raises(contains="Can't parse -c"):
        var _ = Parser.parse[Forms](["-vc=4"])
    with assert_raises(contains="Unknown option: -="):
        var _ = Parser.parse[Forms](["-v=true"])


def test_scalar_last_wins_and_flags_set_true() raises:
    var args = Parser.parse[Forms](
        [
            "--name=first",
            "-nsecond",
            "--name",
            "",
            "--count",
            "2",
            "-c9",
            "--verbose=false",
            "-vv",
            "--quiet",
            "--quiet=false",
        ]
    )
    assert_equal(args.name.value, "")
    assert_equal(args.count.value, 9)
    assert_true(args.verbose.value)
    assert_false(args.quiet.value)
    assert_true(args.quiet.provided)
    var bare = Parser.parse[BoolTest](["--item=false", "--item", "--item"])
    assert_true(bare.item)


def test_collection_repeats_replace_defaults() raises:
    var args = Parser.parse[Forms](
        [
            "-vIsrc",
            "--include",
            "test files",
            "--include=src",
            "-I",
            "",
            "-u3",
            "--unique=1",
            "-u3",
            "file1",
            "file1",
            "",
        ]
    )
    assert_equal(args.include.value, ["src", "test files", "src", ""])
    assert_equal(args.unique.value, {1, 3})
    assert_equal(args.files.value, ["file1", "file1", ""])
    assert_true(args.include.provided)
    assert_true(args.unique.provided)
    assert_true(args.files.provided)
    var defaults = Parser.parse[Forms]([])
    assert_equal(defaults.include.value, ["default-path"])
    assert_equal(defaults.files.value, ["default-file"])
    assert_false(defaults.include.provided)


def test_terminator_and_literal_help_values() raises:
    var args = Parser.parse[Forms](
        ["-qn--help", "--count", "-3", "--", "--verbose=false", "-h", "--", "name"]
    )
    assert_equal(args.name.value, "--help")
    assert_equal(args.count.value, -3)
    assert_equal(args.files.value, ["--verbose=false", "-h", "--", "name"])
    assert_true(args.verbose.value)
    assert_false(args.verbose.provided)
    for value in ["--", "--help", "-h", "--quiet"]:
        var literal = Parser.parse[Forms](["--name", value])
        assert_equal(literal.name.value, value)
        assert_false(literal.quiet.value)
    var bare_flag = Parser.parse[Forms](["--quiet", "false"])
    assert_true(bare_flag.quiet.value)
    assert_equal(bare_flag.files.value, ["false"])
    var negatives = Parser.parse[Forms](["-12", "-"])
    assert_equal(negatives.files.value, ["-12", "-"])


def test_strict_explicit_bool_values() raises:
    for value in ["", "True", "FALSE", "t", "f", "0", "1", "yes", "false ", "--help"]:
        with assert_raises(contains="expected bool (true or false)"):
            var _ = Parser.parse[Forms]([String("--verbose=", value)])


def test_missing_and_malformed_values() raises:
    for option in ["--name", "--count", "-n", "-vc", "--include", "-vI"]:
        with assert_raises(contains="Missing option value"):
            var _ = Parser.parse[Forms]([option])
    for value in ["", "12x", "1.5", "9223372036854775808", "-9223372036854775809"]:
        with assert_raises(contains="Can't parse --count"):
            var _ = Parser.parse[Forms]([String("--count=", value)])
    var maximum = Parser.parse[Forms](["--count=9223372036854775807"])
    assert_equal(maximum.count.value, 9223372036854775807)
    var minimum = Parser.parse[Forms](["--count=-9223372036854775808"])
    assert_equal(minimum.count.value, -9223372036854775808)
    with assert_raises(contains="Can't parse --item"):
        var _ = Parser.parse[FloatTest](["--item=3.5x"])


def test_help_and_error_order() raises:
    var help_cases: List[List[String]] = [
        ["--help", "--missing"],
        ["-vqhx"],
        ["-h", "--count=bad"],
        ["--help", "--help"],
    ]
    for args in help_cases:
        var helped = False
        try:
            var _ = Parser.parse[Forms](args.copy())
        except e:
            assert_true(e.isa[DisplayHelp]())
            helped = True
        assert_true(helped)
    var unknown_cases: List[List[String]] = [["--missing", "--help"], ["-vxh"]]
    for args in unknown_cases:
        with assert_raises(contains="Unknown option"):
            var _ = Parser.parse[Forms](args.copy())
    var invalid_cases: List[List[String]] = [
        ["--count=bad", "--help"],
        ["-vcbad", "-h"],
        ["--count", "--help"],
    ]
    for args in invalid_cases:
        with assert_raises(contains="Can't parse"):
            var _ = Parser.parse[Forms](args.copy())
    with assert_raises(contains="Unknown option"):
        var _ = Parser.parse[Forms](["--help=false", "--help"])
    var help = get_help[Forms]()
    assert_true("-h, --help" in help)
    assert_true("--include=INCLUDE..." in help)
    assert_false("--verbose=" in help)
    assert_false("--quiet=" in help)
    assert_false("--files" in help)


@fieldwise_init
struct RequiredPresence(Defaultable, MojOptDeserializable):
    var count: Opt[Int]

    def __init__(out self):
        self.count = {42}
        self.count.provided = True


def test_stale_presence_does_not_satisfy_required() raises:
    with assert_raises(contains="Missing required option: --count"):
        var _ = Parser.parse[RequiredPresence]([])
    var supplied = Parser.parse[RequiredPresence](["--count=0"])
    assert_true(supplied.count.provided)
    assert_equal(supplied.count.value, 0)


def test_attached_custom_and_nested_values() raises:
    var custom = Parser.parse[Args](["--my-custom=John", "Doe"])
    assert_equal(custom.my_custom.value, CustomType("John", "Doe"))
    assert_true(custom.my_custom.provided)
    var nested = Parser.parse[ArgsBareType](
        [
            "--my-num=4",
            "--complex",
            "--animal=dragon",
            "--thing=table",
            "100",
        ]
    )
    assert_equal(nested.complex.value.animal, "dragon")
    assert_equal(nested.complex.value.many.value, [100])
    assert_true(nested.complex.provided)
    assert_true(nested.complex.value.many.provided)
    var defaults = Parser.parse[ArgsBareType](["--my-num=0"])
    assert_false(defaults.complex.provided)
    assert_false(defaults.complex.value.many.provided)
    var helped = False
    try:
        var _ = Parser.parse[ArgsBareType](["--complex", "--help", "--missing"])
    except e:
        assert_true(e.isa[DisplayHelp]())
        assert_true("--animal=ANIMAL" in e[DisplayHelp].help)
        helped = True
    assert_true(helped)


@fieldwise_init
struct PositionalChoice(Defaultable, MojOptDeserializable):
    var named: Mode
    var positional: Opt[Mode, is_arg=True]

    def __init__(out self):
        self.named = Mode.fast
        self.positional = {Mode.fast}


def test_bare_and_positional_enums() raises:
    var args = Parser.parse[PositionalChoice](["Careful", "--named=dry_run"])
    assert_equal(args.named._get_enum_discriminant(), 2)
    assert_equal(args.positional.value._get_enum_discriminant(), 1)
    assert_true(args.positional.provided)
    with assert_raises(contains="Missing required argument"):
        var _ = Parser.parse[PositionalChoice](["--named=fast"])
    with assert_raises(contains="Expected one of [fast, Careful, dry_run]"):
        var _ = Parser.parse[PositionalChoice](["FAST", "--named=Careful"])
    assert_true("[choices: fast, Careful, dry_run]" in get_help[PositionalChoice]())


def test_names_and_normalization() raises:
    var args = Parser.parse[Args](["--my_custom", "John", "Doe", "--my_string=value"])
    assert_equal(args.my_string.value, "value")
    var overridden = Parser.parse[ArgsBare](["--my_int=8", "-cpath"])
    assert_equal(overridden.my_int, 8)
    assert_equal(overridden.complex.value, ["path"])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
