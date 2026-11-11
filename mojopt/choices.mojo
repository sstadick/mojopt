from std.builtin._enum import __Enum
from std.builtin.variadics import ParameterList, TypeList


def enum_choices[T: __Enum]() -> String:
    """Return the exact names accepted for a payload-free enum."""
    comptime names = ParameterList[T._enum_case_names]()
    comptime types = TypeList[Trait=AnyType, T._enum_case_types]()
    var choices: List[String] = []
    comptime for i in range(len(names)):
        comptime assert types[i] == NoneType, "MojOpt enum choices cannot have payloads"
        choices.append(String(StaticString(names[i])))
    return ", ".join(choices)


def parse_enum[T: __Enum & Movable](value: String, out result: T) raises:
    comptime choices = enum_choices[T]()
    comptime names = ParameterList[T._enum_case_names]()
    comptime for i in range(len(names)):
        if value == StaticString(names[i]):
            result = T.__enum_init[i, NoneType]()
            return
    raise Error(t"Expected one of [{materialize[choices]()}], got '{value}'")
