from std.builtin.rebind import downcast
from std.collections import Set
from std.collections.string.string_slice import _get_kgen_string
from std.memory import ArcPointer, OwnedPointer
from std.os import abort
from std.sys.intrinsics import _type_is_eq

from mojopt.parser import Parser, ParseOptions
from mojopt.error import MojOptErr, DisplayHelp
from mojopt.default import reflection_default
from mojopt.help import get_help


comptime non_struct_error = "Cannot deserialize non-struct type"
comptime _Base = ImplicitlyDestructible & Movable


trait MojOptDeserializable(_Base):
    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        # Validate that there aren't conflicting idents
        comptime _ = __possible_idents[Self]()

        comptime r = reflect[Self]()
        comptime field_count = r.field_count()
        comptime field_names = r.field_names()
        comptime field_types = r.field_types()

        # Check that all defaults are valid
        comptime for i in range(field_count):
            comptime if conforms_to(field_types[i], Optable):
                comptime if downcast[field_types[i], Optable].opt_default_value:
                    comptime assert downcast[
                        field_types[i], Optable
                    ].__valid_default(), StaticString(
                        _get_kgen_string[
                            "TOP: Invalid default value [",
                            ", ".join(downcast[field_types[i], Optable].opt_default_value.value()),
                            "] for type ",
                            r.name(),
                            ".",
                            field_names[i],
                        ]()
                    )

        # Check that there is only one args list
        comptime assert __count_args_appendable[Self]() <= 1, StaticString(
            _get_kgen_string[
                "Multiple possible Appendable arguments for ",
                r.name(),
            ]()
        )

        s = _default_deserialize[Self](p)

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return True


trait MojOptDeserializableAppendable(Appendable, MojOptDeserializable):
    def append_parse[options: ParseOptions, //](mut self, mut p: Parser[options]) raises MojOptErr:
        ...


trait Appendable(_Base):
    def append_to(mut self, var value: Some[Copyable & _Base]):
        ...


trait Optable(MojOptDeserializable):
    comptime opt_help: String
    # TODO: needs parametric traits so this doesn't have to be a string
    comptime opt_default_value: Optional[List[String]]
    comptime opt_defaultable: Bool
    comptime opt_long: Optional[String]
    comptime opt_short: Optional[String]
    comptime opt_is_arg: Bool
    comptime opt_is_flag: Bool

    # Needed untill MOCO-3413 is resolved (conforms_to does not respect where clause and will return True even for where-gated traits)
    comptime opt_is_appendable: Bool

    @staticmethod
    def __valid_default() -> Bool:
        ...


struct Opt[
    # T: MojOptDeserializable,
    T: AnyType & _Base,
    help: String = "",
    default_value: Optional[List[String]] = None,
    defaultable: Bool = False,
    long: Optional[String] = None,
    short: Optional[String] = None,
    is_arg: Bool = False,
](
    Boolable where conforms_to(T, Boolable),
    Defaultable where conforms_to(T, Defaultable),
    Equatable where conforms_to(T, Equatable),
    MojOptDeserializable,
    MojOptDeserializableAppendable where conforms_to(T, MojOptDeserializableAppendable),
    Optable,
    Writable,
):
    comptime opt_help = Self.help
    comptime opt_default_value = Self.default_value
    comptime opt_defaultable = Self.defaultable
    comptime opt_long = Self.long
    comptime opt_short = Self.short
    comptime opt_is_arg = Self.is_arg
    comptime opt_is_flag = _type_is_eq[Self.T, Bool]()

    # Needed until MOCO-3413 is resolved (conforms_to does not respect where clause and will return True even for where-gated traits)
    comptime opt_is_appendable = conforms_to(Self.T, MojOptDeserializableAppendable)

    var value: Self.T

    def __init__(out self, var value: Self.T):
        # comptime assert conforms_to(Self.T, MojOptDeserializable), "MojOptDeserialize must be implemented for Self.T"
        # Comptime validate that the default is parsable
        comptime if Self.opt_default_value:
            comptime assert Self.__valid_default(), StaticString(
                _get_kgen_string[
                    "Invalid default value [",
                    ", ".join(Self.opt_default_value.value()),
                    "] for type ",
                    reflect[Self]().name(),
                ]()
            )
        comptime if Self.opt_defaultable:
            comptime assert conforms_to(Self.T, Defaultable), StaticString(
                _get_kgen_string[
                    "defaultable was specified for ",
                    reflect[Self]().name(),
                    " but ",
                    reflect[Self.T]().name(),
                    " does not implement Defaultable.",
                ]()
            )

        self.value = value^

    def __init__(out self) where conforms_to(Self.T, Defaultable):
        self = reflection_default[Self]()

    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self(_deserialize_impl[Self.T](p))

    def append_parse[
        options: ParseOptions, //
    ](mut self, mut p: Parser[options]) raises MojOptErr where conforms_to(
        Self.T, MojOptDeserializableAppendable
    ):
        self.value.append_parse(p)

    def append_to(
        mut self, var value: Some[Copyable & _Base]
    ) where conforms_to(Self.T, Appendable):
        self.value.append_to(value^)

    @staticmethod
    def _derive_help() -> Bool:
        comptime if conforms_to(Self.T, MojOptDeserializable):
            return downcast[Self.T, MojOptDeserializable]._derive_help()
        else:
            return True

    @staticmethod
    def __valid_default() -> Bool:
        comptime if Self.opt_default_value:
            comptime check = _comptime_deserialize_impl[Self.T](
                Parser[ParseOptions(parsing_mode=ParseOptions.ParsingDefaults)](
                    materialize[Self.opt_default_value]().value().copy()
                )
            )
            comptime if not check.ok:
                return False
            else:
                return True
        return True

    def __bool__(self) -> Bool where conforms_to(Self.T, Boolable):
        return self.value.__bool__()

    def __eq__(self, other: Self) -> Bool where conforms_to(Self.T, Equatable):
        return self.value == other.value

    def write_to(self, mut writer: Some[Writer]):
        comptime if conforms_to(Self.T, Writable):
            writer.write(self.value)
        else:
            writer.write("Opt")


@always_inline
def deserialize[options: ParseOptions, //, T: _Base](mut p: Parser[options], out res: T) raises:
    res = _deserialize_impl[T](p)


@always_inline
def deserialize[options: ParseOptions, //, T: _Base](var p: Parser[options], out res: T) raises:
    res = _deserialize_impl[T](p)


@always_inline
def __is_optional[T: AnyType]() -> Bool:
    return reflect[T]().base_name() == "Optional"


@always_inline
def __is_list[T: AnyType]() -> Bool:
    return reflect[T]().base_name() == "List"


@always_inline
def __is_appendable[T: AnyType]() -> Bool:
    return conforms_to(T, Appendable)


@always_inline
def __is_default[T: AnyType]() -> Bool:
    return reflect[T]().base_name() == "Default"


@always_inline
def __is_opt[T: AnyType]() -> Bool:
    return reflect[T]().base_name() == "Opt"


def __all_dtors_are_trivial[T: AnyType]() -> Bool:
    comptime r = reflect[T]()
    comptime field_types = r.field_types()
    comptime for i in range(r.field_count()):
        comptime type = field_types[i]
        if not downcast[type, ImplicitlyDestructible].__del__is_trivial:
            return False
    return True


def __to_ident(s: String) -> String:
    var prefix_stripped = __strip_prefix_dashes(s)
    var fixed = prefix_stripped.replace("-", "_")
    return fixed


def __to_display_name(s: String) -> String:
    return s.replace("_", "-")


def __strip_prefix_dashes(s: String) -> String:
    if s.startswith("--"):
        return String(s[byte=2:])
    elif s.startswith("-"):
        return String(s[byte=1:])
    return s


def __count_args_appendable[T: _Base]() -> Int:
    comptime r = reflect[T]()
    comptime field_names = r.field_names()
    comptime field_types = r.field_types()

    var count = 0
    comptime for i in range(0, len(field_names)):
        comptime if not reflect[field_types[i]]().is_struct():
            continue
        comptime is_optable = conforms_to(field_types[i], Optable)
        # Needed untill MOCO-3413 is resolved (conforms_to does not respect where clause and will return True even for where-gated traits)
        comptime is_appendable = __is_appendable[field_types[i]]() and (
            not is_optable or downcast[field_types[i], Optable].opt_is_appendable
        )
        comptime if (is_optable and downcast[field_types[i], Optable].opt_is_arg and is_appendable):
            count += 1
        elif not is_optable and reflect[downcast[field_types[i], _Base]]().is_struct():
            count += __count_args_appendable[downcast[field_types[i], _Base]]()

    return count


def __possible_idents[T: _Base]() -> Dict[String, String]:
    """Determine the possible idents for all fields in this struct.

    Idents are the following:
    - The raw name of the field
    - The name of the field, with `-` replaced with `_`
    - Any custom name provided by the user via `Opt.long` and `Opt.short`
        - For any custom names, the same normalization of `-` to `_` takes place
    """
    comptime r = reflect[T]()
    comptime field_names = r.field_names()
    comptime field_types = r.field_types()

    var ret: Dict[String, String] = {}
    comptime for i in range(0, len(field_names)):
        comptime name = field_names[i]

        comptime if __is_opt[field_types[i]]():
            comptime o = downcast[field_types[i], Optable]
            if o.opt_long:
                assert (
                    o.opt_long.value() not in ret
                ), t"Duplicate long opt `{o.opt_long.value()}` in {r.name()} on field {name}."
                ret[__to_ident(o.opt_long.value())] = String(name)
            if o.opt_short:
                assert (
                    o.opt_short.value() not in ret
                ), t"Duplicate short opt `{o.opt_short.value()}` in {r.name()} on field {name}."
                ret[__to_ident(o.opt_short.value())] = String(name)

        ret[__to_ident(name)] = String(name)

    return ret^


@always_inline
def _default_deserialize[
    options: ParseOptions,
    //,
    T: _Base,
](mut p: Parser[options], out s: T) raises MojOptErr:
    comptime if conforms_to(T, Defaultable):
        s = downcast[T, Defaultable]()
    else:
        # If we use mark_initialized with a struct that has something like a pointer
        # field that doesn't become initialized it will cause a crash if parsing fails.
        comptime assert __all_dtors_are_trivial[T](), (
            "Cannot deserialize non-Defaultable struct containing fields with"
            " non-trivial destructors"
        )
        __mlir_op.`lit.ownership.mark_initialized`(__get_mvalue_as_litref(s))

    comptime r = reflect[T]()
    comptime field_count = r.field_count()
    comptime field_names = r.field_names()
    comptime field_types = r.field_types()

    # Fill via key-value pairs

    # maybe an optimization since the InlineArray ctor uses a for loop
    # but according to the IR this will just inline the computed values
    var seen = materialize[InlineArray[Bool, field_count](fill=False)]()
    var possible_idents = materialize[__possible_idents[T]()]()

    comptime help = get_help[downcast[T, MojOptDeserializable]]() if conforms_to(
        T, MojOptDeserializable
    ) else ""

    var positionals: List[String] = []
    while not p.is_done():
        var candidate_ident = p.read_string()
        if candidate_ident.lower() == "--help" or candidate_ident.lower() == "-h":
            raise MojOptErr(DisplayHelp(help))

        var ident = possible_idents.get(__to_ident(candidate_ident))

        if not ident:
            # Actually might be positional argument
            positionals.append(candidate_ident)
            continue

        var matched = False
        comptime for i in range(field_count):
            comptime name = field_names[i]
            comptime field_type = field_types[i]
            comptime is_optable = conforms_to(field_type, Optable)

            if ident.value() == name:
                ref seen_i = seen.unsafe_get(i)

                comptime if is_optable and downcast[field_type, Optable].opt_is_arg:
                    raise MojOptErr(
                        Error(t"{candidate_ident} is a positional argument, not an option.")
                    )

                ref field = trait_downcast[_Base](r.field_ref[i](s))
                comptime TField = downcast[type_of(field), _Base]
                comptime is_appendable = __is_appendable[TField]() and (
                    not is_optable or downcast[field_type, Optable].opt_is_appendable
                )

                # MojOptTraits - all okay because we've checked if TField/field is_optable, which in turn means it impls MojOptTraits
                comptime if is_appendable:
                    trait_downcast[MojOptDeserializableAppendable](field).append_parse(p)
                elif _type_is_eq[TField, Bool]() or (
                    is_optable and downcast[field_type, Optable].opt_is_flag
                ):
                    if seen_i:
                        raise MojOptErr(Error(t"Duplicate option: {candidate_ident}"))
                    comptime if is_optable and Bool(
                        downcast[field_type, Optable].opt_default_value
                    ):
                        # Invert whatever the supplied default was
                        comptime value = downcast[field_type, Optable].opt_default_value.value()
                        var p_bool = Parser(materialize[value]().copy())
                        var b = p_bool.read_bool()
                        # TODO: this should be doable without re-parsing
                        # but we go through it since field could be Bool or Opt[Bool]
                        # To fix it need to create a default of field, then invert it
                        if b:
                            # Was true, invert
                            var p = Parser(["False"])
                            field = downcast[type_of(field), MojOptDeserializable].from_opts(p)
                        else:
                            var p = Parser(["True"])
                            field = downcast[type_of(field), MojOptDeserializable].from_opts(p)
                    elif is_optable:  # Flags are assumed set to default of False
                        # TODO: technically this ignores the defaultable setting on Opts
                        # Needs same fix as above
                        var p = Parser(["True"])
                        field = downcast[type_of(field), MojOptDeserializable].from_opts(p)
                    else:
                        # TODO: technically this ignores the defaultable setting on Opts
                        # Needs same fix as above
                        # Since the default for bool is False, invert it to true
                        field = rebind_var[type_of(field)](True)
                else:
                    if seen_i:
                        raise MojOptErr(Error(t"Duplicate option: {candidate_ident}"))
                    try:
                        field = _deserialize_impl[TField](p)
                    except e:
                        raise MojOptErr(Error(t"Can't parse {candidate_ident}'s value:\n\t{e}"))

                seen_i = True
                matched = True

        if not matched:
            raise MojOptErr(Error(t"Unexpected field: {candidate_ident}"))

    # Check for positional arguments
    if positionals:
        var pp = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingArguments)](positionals^)
        comptime for i in range(field_count):
            comptime is_optable = conforms_to(field_types[i], Optable)

            if pp.is_done():
                break

            comptime if is_optable and downcast[field_types[i], Optable].opt_is_arg:
                ref seen_i = seen.unsafe_get(i)
                seen_i = True
                ref field = trait_downcast[_Base](r.field_ref[i](s))
                comptime TField = downcast[type_of(field), _Base]
                try:
                    field = _deserialize_impl[type_of(field)](pp)
                except e:
                    raise MojOptErr(
                        Error(
                            "Can't parse positional argument"
                            + String(t" [{materialize[field_names[i]]().upper()}]:\n\t{e}")
                        )
                    )

        if not pp.is_done():
            raise MojOptErr(Error(t"Unexpected fields: {', '.join(pp.data)}"))

    comptime for i in range(field_count):
        # We didn't find a key value pairing
        if not seen.unsafe_get(i):
            comptime is_optable = conforms_to(field_types[i], Optable)

            # Must wrap in bool to avoid incompatible type error
            comptime if is_optable and Bool(downcast[field_types[i], Optable].opt_default_value):
                # First try to get a default from the metadata
                comptime default = downcast[field_types[i], Optable].opt_default_value.value()
                ref field = trait_downcast[_Base](r.field_ref[i](s))
                var p = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingDefaults)](
                    materialize[default]()
                )
                field = downcast[type_of(field), MojOptDeserializable].from_opts(p)
            elif __is_optional[field_types[i]]() or (
                is_optable
                and downcast[field_types[i], Optable].opt_defaultable
                and conforms_to(field_types[i], Defaultable)
            ):
                # Then check if defaultable or optional

                ref field = trait_downcast[Movable & Defaultable](r.field_ref[i](s))
                UnsafePointer(to=field).init_pointee_move(type_of(field)())

            else:
                # Explode

                comptime name = String(
                    downcast[field_types[i], Optable].opt_long.value()
                ) if is_optable and Bool(downcast[field_types[i], Optable].opt_long) else String(
                    field_names[i]
                )
                comptime if is_optable and Bool(downcast[field_types[i], Optable].opt_is_arg):
                    raise MojOptErr(Error("Missing required argument: [", name.upper(), "]"))
                else:
                    raise MojOptErr(Error("Missing required option: --", name))


def _deserialize_impl[
    options: ParseOptions, //, T: _Base
](mut p: Parser[options], out s: T) raises MojOptErr:
    comptime assert reflect[T]().is_struct(), non_struct_error

    comptime if conforms_to(T, MojOptDeserializable):
        s = downcast[T, MojOptDeserializable].from_opts(p)
    else:
        s = _default_deserialize[T](p)


def _comptime_deserialize_impl[
    options: ParseOptions, //, T: _Base
](var p: Parser[options]) -> DefaultDeserCheck:
    try:
        s = _deserialize_impl[T](p)
        if p.is_done():
            return DefaultDeserCheck(True, None)
        else:
            return DefaultDeserCheck(False, "Not all values in parser consumed.")
    except e:
        return DefaultDeserCheck(False, String(e))


@fieldwise_init
struct DefaultDeserCheck(Movable, Writable):
    var ok: Bool
    var error: Optional[String]


# ===============================================
# Primitives
# ===============================================


__extension String(MojOptDeserializable):
    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = p.read_string()

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


__extension Int(MojOptDeserializable):
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Int(p.read_int())

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


__extension SIMD(MojOptDeserializable):
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        comptime assert Self.size == 1, "Currenlty only Scalars are supported by MojOpt"
        s = Self()
        comptime if Self.dtype.is_numeric():
            comptime if Self.dtype.is_floating_point():
                return p.read_float[Self.dtype]()
            else:
                return p.read_int[Self.dtype]()
        else:
            return Scalar[Self.dtype](p.read_bool())

        raise Error(t"No way to parse {Self.dtype}")

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


__extension Bool(MojOptDeserializable):
    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = p.read_bool()

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


__extension IntLiteral(MojOptDeserializable):
    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self()
        var i = p.read_int()
        if i != s:
            raise Error(t"Expected {s}, got {i}")

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


__extension FloatLiteral(MojOptDeserializable):
    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self()
        var i = p.read_float()
        if i != s:
            raise Error(t"Expected {s}, got {i}")

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


# ===============================================
# Pointers
# ===============================================


__extension ArcPointer(MojOptDeserializable):
    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self(_deserialize_impl[downcast[Self.T, _Base]](p))

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


__extension OwnedPointer(MojOptDeserializable):
    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = rebind_var[Self](OwnedPointer(_deserialize_impl[downcast[Self.T, _Base]](p)))

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


# ===============================================
# Collections
# ===============================================


__extension Optional(MojOptDeserializable):
    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self(_deserialize_impl[downcast[Self.T, _Base]](p))

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


__extension List(MojOptDeserializableAppendable):
    def append_to(mut self, var value: Some[Copyable & _Base]):
        self.append(rebind_var[Self.T](value^))

    def append_parse[options: ParseOptions, //](mut self, mut p: Parser[options]) raises MojOptErr:
        var deser = _deserialize_impl[downcast[Self.T, _Base]](p)  # _Base
        var value = trait_downcast_var[Copyable & _Base](deser^)  # implicitly Self.T
        self.append_to(value^)

    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self()

        comptime if options.parsing_mode == ParseOptions.ParsingArguments:
            # If we are argument parsing, consume all the values possible
            while not p.is_done():
                s.append(_deserialize_impl[downcast[Self.T, _Base]](p))
        elif options.parsing_mode == ParseOptions.ParsingOptions:
            # If we are still option parsing, lists will come as kv pairs still
            s.append(_deserialize_impl[downcast[Self.T, _Base]](p))
        elif options.parsing_mode == ParseOptions.ParsingDefaults:
            # Parsing a user defined default value
            while not p.is_done():
                s.append(_deserialize_impl[downcast[Self.T, _Base]](p))
        else:
            abort(t"Unknown parse mode: {options.parsing_mode}")

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


__extension Set(MojOptDeserializableAppendable):
    def append_to(mut self, var value: Some[Copyable & _Base]):
        self.add(rebind_var[Self.T](value^))

    def append_parse[options: ParseOptions, //](mut self, mut p: Parser[options]) raises MojOptErr:
        var deser = _deserialize_impl[downcast[Self.T, _Base]](p)  # _Base
        var value = trait_downcast_var[Copyable & _Base](deser^)  # implicitly Self.T
        self.append_to(value^)

    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self()

        comptime if options.parsing_mode == ParseOptions.ParsingArguments:
            # If we are argument parsing, consume all the values possible
            while not p.is_done():
                s.add(_deserialize_impl[downcast[Self.T, _Base]](p))
        elif options.parsing_mode == ParseOptions.ParsingOptions:
            # If we are still option parsing, lists will come as kv pairs still
            s.add(_deserialize_impl[downcast[Self.T, _Base]](p))
        elif options.parsing_mode == ParseOptions.ParsingDefaults:
            # Parsing a user defined default value
            while not p.is_done():
                s.add(_deserialize_impl[downcast[Self.T, _Base]](p))
        else:
            abort(t"Unknown parse mode: {options.parsing_mode}")

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


__extension InlineArray(MojOptDeserializable):
    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self(uninitialized=True)
        comptime assert (
            options.parsing_mode != ParseOptions.ParsingOptions
        ), "Cannot use fixed-size container as an option"

        comptime if (
            options.parsing_mode == ParseOptions.ParsingArguments
            or options.parsing_mode == ParseOptions.ParsingDefaults
        ):
            # If we are argument parsing, consume all the values possible
            comptime for i in range(Self.size):
                if p.is_done():
                    raise Error(t"Found {i} values, expected {len(s)}")
                UnsafePointer(to=s[i]).init_pointee_move(
                    _deserialize_impl[downcast[Self.ElementType, _Base]](p)
                )
        elif options.parsing_mode == ParseOptions.ParsingOptions:
            raise Error("Cannot use fixed-size container as an option")
        else:
            abort(t"Unknown parse mode: {options.parsing_mode}")

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False


__extension Tuple(MojOptDeserializable):
    @staticmethod
    def from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        __mlir_op.`lit.ownership.mark_initialized`(__get_mvalue_as_litref(s))
        comptime assert (
            options.parsing_mode != ParseOptions.ParsingOptions
        ), "Cannot use fixed-size container as an option"

        comptime if (
            options.parsing_mode == ParseOptions.ParsingArguments
            or options.parsing_mode == ParseOptions.ParsingDefaults
        ):
            # If we are argument parsing, consume all the values possible
            comptime for i in range(Self.__len__()):
                if p.is_done():
                    raise Error(t"Found {i} values, expected {len(s)}")
                UnsafePointer(to=s[i]).init_pointee_move(
                    _deserialize_impl[downcast[Self.element_types[i], _Base]](p)
                )
        elif options.parsing_mode == ParseOptions.ParsingOptions:
            raise Error("Cannot use fixed-size container as an option")
        else:
            abort(t"Unknown parse mode: {options.parsing_mode}")

    @staticmethod
    def description() -> String:
        return ""

    @staticmethod
    def _derive_help() -> Bool:
        return False
