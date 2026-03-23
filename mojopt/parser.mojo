from std.sys import argv

from mojopt.deserialize import MojOptDeserializable, _Base
from mojopt.error import MojOptErr


struct ParseOptions(Equatable, TrivialRegisterPassable):
    comptime ParsingOptions: Int = 1
    """Indicates that we are parsing key-value paired options."""
    comptime ParsingArguments: Int = 2
    """Indicates that we are parsing non-key-value paired arguments."""
    comptime ParsingDefaults: Int = 3
    """Indicates that we are parsing user defined default values."""

    var parsing_mode: Int

    fn __init__(out self, *, parsing_mode: Int = Self.ParsingOptions):
        self.parsing_mode = parsing_mode


struct Parser[options: ParseOptions = ParseOptions()]:
    var cursor: Int
    var data: List[String]

    fn __init__(out self):
        self.cursor = 0
        # Skip the first arg as it's the program name.
        self.data = [String(s) for s in argv()[1:]]

    fn __init__(out self, var args: List[String]):
        self.cursor = 0
        self.data = args^

    @staticmethod
    def parse[T: MojOptDeserializable & _Base]() raises MojOptErr -> T:
        var parser = Parser()
        return T.from_opts(parser)

    @staticmethod
    def parse[T: MojOptDeserializable & _Base](var args: List[String]) raises MojOptErr -> T:
        var parser = Parser(args^)
        return T.from_opts(parser)

    fn is_done(read self) -> Bool:
        return self.cursor == len(self.data)

    fn _get_next(mut self) -> String:
        debug_assert(
            self.cursor < len(self.data),
            "Parser cursor has gone past end of data.",
        )
        var value = self.data[self.cursor]
        self.cursor += 1
        return value

    fn read_string(mut self) -> String:
        # TODO: return ref
        return self._get_next()

    def read_bool(mut self) raises -> Bool:
        var value = self._get_next().lower()
        if value == "true" or value == "t":
            return True
        elif value == "false" or value == "f":
            return False
        else:
            raise Error("Expected bool, got: " + value)

    def read_int[type: DType = DType.int64](mut self) raises -> Scalar[type]:
        comptime assert type.is_integral(), "Ints are integral"
        var value = self._get_next()
        return Scalar[type](atol(value))

    def read_float[type: DType = DType.float64](mut self) raises -> Scalar[type]:
        comptime assert type.is_floating_point(), "Floats are floating point"
        var value = self._get_next()
        return Scalar[type](atof(value))
