"""Regression tests for partially initialized fixed-size argument containers."""

from std.memory import OwnedPointer
from std.testing import assert_equal, assert_raises, TestSuite

from mojopt.deserialize import MojOptDeserializable
from mojopt.error import MojOptErr
from mojopt.parser import Parser, ParseOptions

comptime Arguments = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingArguments)]
comptime Defaults = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingDefaults)]


struct Resource(MojOptDeserializable):
    """A non-defaultable, non-copyable element with a non-trivial move constructor."""

    var value: OwnedPointer[String]

    def __init__(out self, var value: String):
        self.value = OwnedPointer(value^)

    def __init__(out self, *, deinit move: Self):
        self.value = move.value^

    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        var value = p.read_string()
        if value == "bad":
            raise Error("Invalid resource")
        s = Self(value^)


def test_resource_array() raises:
    var parser = Arguments(["one", "two", "three"])
    var values = Array[Resource, 3].from_opts(parser)
    assert_equal(values[0].value[], "one")
    assert_equal(values[1].value[], "two")
    assert_equal(values[2].value[], "three")


def test_resource_array_cleanup() raises:
    # Exercise every possible initialized prefix, both EOF and a raising element parser.
    for prefix in range(3):
        var args = List[String]()
        for i in range(prefix):
            args.append(String(i))
        var too_short = Arguments(args.copy())
        with assert_raises():
            var _ = Array[Resource, 3].from_opts(too_short)
        args.append("bad")
        var invalid = Arguments(args^)
        with assert_raises():
            var _ = Array[Resource, 3].from_opts(invalid)


def test_resource_tuple() raises:
    var parser = Arguments(["one", "two", "three"])
    var values = Tuple[Resource, Resource, Resource].from_opts(parser)
    assert_equal(values[0].value[], "one")
    assert_equal(values[1].value[], "two")
    assert_equal(values[2].value[], "three")


def test_resource_tuple_cleanup() raises:
    for prefix in range(3):
        var args = List[String]()
        for i in range(prefix):
            args.append(String(i))
        var too_short = Arguments(args.copy())
        with assert_raises():
            var _ = Tuple[Resource, Resource, Resource].from_opts(too_short)
        args.append("bad")
        var invalid = Arguments(args^)
        with assert_raises():
            var _ = Tuple[Resource, Resource, Resource].from_opts(invalid)


def test_nested_container_cleanup() raises:
    var array_parser = Arguments(["one", "two", "three", "bad"])
    with assert_raises():
        var _ = Array[Tuple[Resource, Resource], 2].from_opts(array_parser)
    var tuple_parser = Arguments(["one", "two", "three", "bad"])
    with assert_raises():
        var _ = Tuple[Resource, Array[Resource, 3]].from_opts(tuple_parser)


def test_container_defaults() raises:
    var array_parser = Defaults(["one", "two"])
    var array = Array[Resource, 2].from_opts(array_parser)
    assert_equal(array[1].value[], "two")
    var tuple_parser = Defaults(["one", "two"])
    var tuple = Tuple[Resource, String].from_opts(tuple_parser)
    assert_equal(tuple[0].value[], "one")
    assert_equal(tuple[1], "two")


def test_empty_containers() raises:
    var parser = Arguments([])
    var array = Array[Resource, 0].from_opts(parser)
    var tuple = Tuple[].from_opts(parser)
    assert_equal(len(array), 0)
    assert_equal(len(tuple), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
