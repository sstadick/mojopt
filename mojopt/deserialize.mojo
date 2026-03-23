from std.builtin.rebind import downcast
from std.collections import Set
from std.collections.string.string_slice import _get_kgen_string
from std.memory import ArcPointer, OwnedPointer
from std.os import abort
from std.reflection import (
    struct_field_count,
    struct_field_types,
    struct_field_names,
    is_struct_type,
    get_base_type_name,
    get_type_name,
)
from std.sys.intrinsics import _type_is_eq

from mojopt.parser import Parser, ParseOptions
from mojopt.error import MojOptErr, DisplayHelp
from mojopt.default import reflection_default


comptime non_struct_error = "Cannot deserialize non-struct type"
comptime _Base = ImplicitlyDestructible & Movable


trait MojOptDeserializable(_Base):
    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        # Validate that there aren't conflicting idents
        comptime _ = __possible_idents[Self]()

        comptime field_count = struct_field_count[Self]()
        comptime field_names = struct_field_names[Self]()
        comptime field_types = struct_field_types[Self]()

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
                            get_type_name[Self](),
                            ".",
                            field_names[i],
                        ]()
                    )

        # Check that there is only one args list
        comptime assert __count_args_appendable[Self]() <= 1, StaticString(
            _get_kgen_string[
                "Multiple possible Appendable arguments for ",
                get_type_name[Self](),
            ]()
        )

        s = _default_deserialize[Self](p)

    @staticmethod
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return True


trait MojOptDeserializableAppendable(Appendable, MojOptDeserializable):
    fn append_parse[options: ParseOptions, //](mut self, mut p: Parser[options]) raises MojOptErr:
        ...


trait Appendable(_Base):
    fn append_to(mut self, var value: Some[Copyable & _Base]):
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
    fn __valid_default() -> Bool:
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

    fn __init__(out self, var value: Self.T):
        # comptime assert conforms_to(Self.T, MojOptDeserializable), "MojOptDeserialize must be implemented for Self.T"
        # Comptime validate that the default is parsable
        comptime if Self.opt_default_value:
            comptime assert Self.__valid_default(), StaticString(
                _get_kgen_string[
                    "Invalid default value [",
                    ", ".join(Self.opt_default_value.value()),
                    "] for type ",
                    get_type_name[Self](),
                ]()
            )
        comptime if Self.opt_defaultable:
            comptime assert conforms_to(Self.T, Defaultable), StaticString(
                _get_kgen_string[
                    "defaultable was specified for ",
                    get_type_name[Self](),
                    " but ",
                    get_type_name[Self.T](),
                    " does not implement Defaultable.",
                ]()
            )

        self.value = value^

    fn __init__(out self) where conforms_to(Self.T, Defaultable):
        self = reflection_default[Self]()

    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self(_deserialize_impl[Self.T](p))

    fn append_parse[
        options: ParseOptions, //
    ](mut self, mut p: Parser[options]) raises MojOptErr where conforms_to(
        Self.T, MojOptDeserializableAppendable
    ):
        trait_downcast[MojOptDeserializableAppendable](self.value).append_parse(p)

    fn append_to(mut self, var value: Some[Copyable & _Base]) where conforms_to(Self.T, Appendable):
        trait_downcast[Appendable](self.value).append_to(value^)

    @staticmethod
    fn _derive_help() -> Bool:
        comptime if conforms_to(Self.T, MojOptDeserializable):
            return downcast[Self.T, MojOptDeserializable]._derive_help()
        else:
            return True

    @staticmethod
    fn __valid_default() -> Bool:
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

    fn __bool__(self) -> Bool where conforms_to(Self.T, Boolable):
        return trait_downcast[Boolable](self.value).__bool__()

    fn __eq__(self, other: Self) -> Bool where conforms_to(Self.T, Equatable):
        return trait_downcast[Equatable](self.value).__eq__(trait_downcast[Equatable](other.value))

    fn write_to(self, mut writer: Some[Writer]):
        comptime if conforms_to(Self.T, Writable):
            writer.write(trait_downcast[Writable](self.value))
        else:
            writer.write("Opt")


@always_inline
fn try_deserialize[T: _Base](s: List[StaticString]) -> Optional[T]:
    return try_deserialize[T](Parser(s))


fn try_deserialize[options: ParseOptions, //, T: _Base](var p: Parser[options]) -> Optional[T]:
    try:
        return _deserialize_impl[T](p)
    except:
        return None


@always_inline
fn deserialize[T: _Base](s: VariadicList[StaticString], out res: T) raises:
    res = deserialize[T](Parser(s))


@always_inline
fn deserialize[options: ParseOptions, //, T: _Base](mut p: Parser[options], out res: T) raises:
    res = _deserialize_impl[T](p)


@always_inline
fn deserialize[options: ParseOptions, //, T: _Base](var p: Parser[options], out res: T) raises:
    res = _deserialize_impl[T](p)


@always_inline
fn __is_optional[T: AnyType]() -> Bool:
    return get_base_type_name[T]() == "Optional"


@always_inline
fn __is_list[T: AnyType]() -> Bool:
    return get_base_type_name[T]() == "List"


@always_inline
fn __is_appendable[T: AnyType]() -> Bool:
    return conforms_to(T, Appendable)


@always_inline
fn __is_default[T: AnyType]() -> Bool:
    return get_base_type_name[T]() == "Default"


@always_inline
fn __is_opt[T: AnyType]() -> Bool:
    return get_base_type_name[T]() == "Opt"


fn __all_dtors_are_trivial[T: AnyType]() -> Bool:
    comptime field_types = struct_field_types[T]()
    comptime for i in range(struct_field_count[T]()):
        comptime type = field_types[i]
        if not downcast[type, ImplicitlyDestructible].__del__is_trivial:
            return False
    return True


fn __to_ident(s: String) -> String:
    var prefix_stripped = __strip_prefix_dashes(s)
    var fixed = prefix_stripped.replace("-", "_")
    return fixed


fn __to_display_name(s: String) -> String:
    return s.replace("_", "-")


fn __strip_prefix_dashes(s: String) -> String:
    if s.startswith("--"):
        return String(s[byte=2:])
    elif s.startswith("-"):
        return String(s[byte=1:])
    return s


fn __count_args_appendable[T: _Base]() -> Int:
    comptime field_names = struct_field_names[T]()
    comptime field_types = struct_field_types[T]()

    var count = 0
    comptime for i in range(0, len(field_names)):
        comptime if not is_struct_type[field_types[i]]():
            continue
        comptime is_optable = conforms_to(field_types[i], Optable)
        # Needed untill MOCO-3413 is resolved (conforms_to does not respect where clause and will return True even for where-gated traits)
        comptime is_appendable = __is_appendable[field_types[i]]() and (
            not is_optable or downcast[field_types[i], Optable].opt_is_appendable
        )
        comptime if (is_optable and downcast[field_types[i], Optable].opt_is_arg and is_appendable):
            count += 1
        elif not is_optable and is_struct_type[downcast[field_types[i], _Base]]():
            count += __count_args_appendable[downcast[field_types[i], _Base]]()

    return count


fn __possible_idents[T: _Base]() -> Dict[String, String]:
    """Determine the possible idents for all fields in this struct.

    Idents are the following:
    - The raw name of the field
    - The name of the field, with `-` replaced with `_`
    - Any custom name provided by the user via `Opt.long` and `Opt.short`
        - For any custom names, the same normalization of `-` to `_` takes place
    """
    comptime field_names = struct_field_names[T]()
    comptime field_types = struct_field_types[T]()

    var ret: Dict[String, String] = {}
    comptime for i in range(0, len(field_names)):
        comptime name = field_names[i]

        comptime if __is_opt[field_types[i]]():
            comptime o = downcast[field_types[i], Optable]
            if o.opt_long:
                assert o.opt_long.value() not in ret, (
                    t"Duplicate long opt `{o.opt_long.value()}` in"
                    t" {get_type_name[T]()} on field {name}."
                )
                ret[__to_ident(o.opt_long.value())] = String(name)
            if o.opt_short:
                assert o.opt_short.value() not in ret, (
                    t"Duplicate short opt `{o.opt_short.value()}` in"
                    t" {get_type_name[T]()} on field {name}."
                )
                ret[__to_ident(o.opt_short.value())] = String(name)

        ret[__to_ident(name)] = String(name)

    return ret^


@always_inline
fn _default_deserialize[
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

    comptime field_count = struct_field_count[T]()
    comptime field_names = struct_field_names[T]()
    comptime field_types = struct_field_types[T]()

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

                ref field = trait_downcast[_Base](__struct_field_ref(i, s))
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
                ref field = trait_downcast[_Base](__struct_field_ref(i, s))
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
                ref field = trait_downcast[_Base](__struct_field_ref(i, s))
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

                ref field = trait_downcast[Movable & Defaultable](__struct_field_ref(i, s))
                UnsafePointer(to=field).init_pointee_move(type_of(field)())

            else:
                # Explode

                comptime name = downcast[
                    field_types[i], Optable
                ].opt_long.value() if is_optable and Bool(
                    downcast[field_types[i], Optable].opt_long
                ) else field_names[
                    i
                ]
                comptime if is_optable and Bool(downcast[field_types[i], Optable].opt_is_arg):
                    raise MojOptErr(Error("Missing required argument: [", name.upper(), "]"))
                else:
                    raise MojOptErr(Error("Missing required option: --", name))


fn _deserialize_impl[
    options: ParseOptions, //, T: _Base
](mut p: Parser[options], out s: T) raises MojOptErr:
    comptime assert is_struct_type[T](), non_struct_error

    comptime if conforms_to(T, MojOptDeserializable):
        s = downcast[T, MojOptDeserializable].from_opts(p)
    else:
        s = _default_deserialize[T](p)


fn _comptime_deserialize_impl[
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


fn get_help[T: _Base, indent_level: Int = 1]() -> String:
    comptime field_names = struct_field_names[T]()
    comptime field_types = struct_field_types[T]()

    var options: List[String] = []
    var arguments: List[String] = []
    var description: String
    comptime if conforms_to(T, MojOptDeserializable) and not __is_opt[T]():
        description = "\n".join(
            [line.lstrip() for line in downcast[T, MojOptDeserializable].description().splitlines()]
        )
    else:
        description = ""

    comptime for i in range(0, len(field_names)):
        comptime field_type = field_types[i]
        comptime field_name = field_names[i]
        comptime type_name = get_base_type_name[field_type]()

        comptime if not is_struct_type[field_type]():
            continue

        comptime if not __is_opt[T]():
            comptime if conforms_to(field_type, Optable):
                comptime optlike = downcast[field_types[i], Optable]
                comptime short_name = String(
                    t"-{optlike.opt_short.value()}), "
                ) if optlike.opt_short else ""
                comptime long_name = String(
                    t"{optlike.opt_long.value()}"
                ) if optlike.opt_long else String(t"{__to_display_name(field_name)}")
                # TODO: with parametric traits this would be a lot better
                # Relying on Opt implementing Writable to transparently show Opt.T
                comptime default = (
                    String(
                        t" [default: `{' '.join(optlike.opt_default_value.value())}`]"
                    ) if optlike.opt_default_value else String(
                        t" [default: `{downcast[field_type, Defaultable & Writable]()}`]"
                    ) if optlike.opt_defaultable
                    and conforms_to(field_type, Writable) else String(
                        " [default: `<default_not_writable>`]"
                    )
                )
                comptime appendable = "..." if optlike.opt_is_appendable else ""
                comptime fixed_help = optlike.opt_help.replace("\n", "          \n")
                comptime desc_line = t"          {fixed_help}"

                comptime if optlike.opt_is_arg:
                    comptime details_line = String(
                        t"  [{long_name.upper()}]{appendable}{default}\n"
                    )
                    arguments.append(materialize[String(details_line) + String(desc_line)]())
                else:
                    comptime details_line = String(
                        t"  {short_name}--{long_name} <{long_name.upper()}>{appendable}{default}\n"
                    )
                    options.append(materialize[String(details_line) + String(desc_line)]())
            else:
                comptime long_name = String(t"  --{field_name} <{field_name.upper()}>")
                options.append(materialize[long_name]())

        comptime if conforms_to(field_type, MojOptDeserializable) and not downcast[
            field_type, MojOptDeserializable
        ]._derive_help():
            continue

        comptime derived_indent = 0 if __is_opt[T]() else indent_level + 1
        var more_help = [
            String(t"{'     ' * derived_indent}{line}")
            for line in get_help[downcast[field_type, _Base], derived_indent + 1]().splitlines()
            if line
        ]
        for line in more_help:
            options.append(line)

    var final_list = [description]
    if len(arguments) > 0:
        if not __is_opt[T]():
            final_list.append("Arguments:")
        final_list.append("\n".join(arguments))

    if len(options) > 0:
        if not __is_opt[T]():
            final_list.append("Options:")
        final_list.append("\n".join(options))

    var final = "\n".join(final_list)
    return final


# ===============================================
# Primitives
# ===============================================


__extension String(MojOptDeserializable):
    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = p.read_string()

    @staticmethod
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


__extension Int(MojOptDeserializable):
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Int(p.read_int())

    @staticmethod
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


__extension SIMD(MojOptDeserializable):
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
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
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


__extension Bool(MojOptDeserializable):
    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = p.read_bool()

    @staticmethod
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


__extension IntLiteral(MojOptDeserializable):
    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self()
        var i = p.read_int()
        if i != s:
            raise Error(t"Expected {s}, got {i}")

    @staticmethod
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


__extension FloatLiteral(MojOptDeserializable):
    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self()
        var i = p.read_float()
        if i != s:
            raise Error(t"Expected {s}, got {i}")

    @staticmethod
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


# ===============================================
# Pointers
# ===============================================


__extension ArcPointer(MojOptDeserializable):
    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self(_deserialize_impl[downcast[Self.T, _Base]](p))

    @staticmethod
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


__extension OwnedPointer(MojOptDeserializable):
    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = rebind_var[Self](OwnedPointer(_deserialize_impl[downcast[Self.T, _Base]](p)))

    @staticmethod
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


# ===============================================
# Collections
# ===============================================


__extension Optional(MojOptDeserializable):
    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
        s = Self(_deserialize_impl[downcast[Self.T, _Base]](p))

    @staticmethod
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


__extension List(MojOptDeserializableAppendable):
    fn append_to(mut self, var value: Some[Copyable & _Base]):
        self.append(rebind_var[Self.T](value^))

    fn append_parse[options: ParseOptions, //](mut self, mut p: Parser[options]) raises MojOptErr:
        var deser = _deserialize_impl[downcast[Self.T, _Base]](p)  # _Base
        var value = trait_downcast_var[Copyable & _Base](deser^)  # implicitly Self.T
        self.append_to(value^)

    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
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
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


__extension Set(MojOptDeserializableAppendable):
    fn append_to(mut self, var value: Some[Copyable & _Base]):
        self.add(rebind_var[Self.T](value^))

    fn append_parse[options: ParseOptions, //](mut self, mut p: Parser[options]) raises MojOptErr:
        var deser = _deserialize_impl[downcast[Self.T, _Base]](p)  # _Base
        var value = trait_downcast_var[Copyable & _Base](deser^)  # implicitly Self.T
        self.append_to(value^)

    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
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
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


__extension InlineArray(MojOptDeserializable):
    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
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
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False


__extension Tuple(MojOptDeserializable):
    @staticmethod
    fn from_opts[options: ParseOptions, //](mut p: Parser[options], out s: Self) raises MojOptErr:
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
    fn description() -> String:
        return ""

    @staticmethod
    fn _derive_help() -> Bool:
        return False
