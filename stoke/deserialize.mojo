from std.reflection import (
    struct_field_count,
    struct_field_types,
    struct_field_names,
    is_struct_type,
    get_base_type_name,
)
from std.os import abort

from .parser import Parser, ParseOptions

from std.builtin.rebind import downcast
from std.collections import Set
from std.memory import ArcPointer, OwnedPointer
from std.sys.intrinsics import unlikely, _type_is_eq
from std.hashlib.hasher import Hasher


comptime non_struct_error = "Cannot deserialize non-struct type"


comptime _Base = ImplicitlyDestructible & Movable


# TODO: What we need to be doing is passing in our cli-parser object
# that should be able to give back fields by name I think


struct OptHelp(Copyable, Hashable, Writable, _Base):
    var help_msg: String
    """Help message to display."""

    var default_value: Optional[String]
    """String version of a default value.

    If None, this is a required option.
    """

    var long_opt: Optional[String]
    """The long option name to use, ex: `--my-value`.
    
    If this is None, the field name will be used, with `_` converted to `-`.
    Note that if a value is provided, no transformation will be applied to it.
    """

    var short_opt: Optional[String]
    """The short option name to use, ex: `-v`.

    If this is None, no short options be allowed for this field.
    """

    var is_arg: Bool
    """Whether or not this is a positional argument."""

    fn __init__(
        out self,
        *,
        help_msg: String,
        default_value: Optional[String] = None,
        long_opt: Optional[String] = None,
        short_opt: Optional[String] = None,
        is_arg: Bool = False
    ):
        self.help_msg = help_msg
        self.default_value = default_value
        self.long_opt = long_opt
        self.short_opt = short_opt
        self.is_arg = is_arg


trait JsonDeserializable(_Base):
    @staticmethod
    fn from_json[
        options: ParseOptions, //
    ](mut p: Parser[options], out s: Self) raises:
        s = _default_deserialize[Self, Self.deserialize_as_array()](p)

    @staticmethod
    fn deserialize_as_array() -> Bool:
        return False

    # TODO: have this as an associate const instead
    @staticmethod
    fn opt_metadata() -> Dict[String, OptHelp]:
        print("Calling default")
        return {}

trait JsonDeserializableAppendable(JsonDeserializable, Appendable):
    fn append_from_json[options: ParseOptions, //](mut self, mut p: Parser[options]) raises:
        # comptime assert(conforms_to(Self, Appendable))
        ...


trait Appendable(_Base):
    fn append_to(mut self, var value: Some[Copyable & _Base]):
        ...
    

@always_inline
fn try_deserialize[T: _Base](s: List[StaticString]) -> Optional[T]:
    return try_deserialize[T](Parser(s))


fn try_deserialize[
    options: ParseOptions, //, T: _Base
](var p: Parser[options]) -> Optional[T]:
    try:
        return _deserialize_impl[T](p)
    except:
        return None


# TODO: version that takes a list


@always_inline
fn deserialize[T: _Base](s: VariadicList[StaticString], out res: T) raises:
    res = deserialize[T](Parser(s))


@always_inline
fn deserialize[
    options: ParseOptions, //, T: _Base
](mut p: Parser[options], out res: T) raises:
    res = _deserialize_impl[T](p)


@always_inline
fn deserialize[
    options: ParseOptions, //, T: _Base
](var p: Parser[options], out res: T) raises:
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


fn __all_dtors_are_trivial[T: AnyType]() -> Bool:
    comptime field_types = struct_field_types[T]()
    comptime for i in range(struct_field_count[T]()):
        comptime type = field_types[i]
        if not downcast[type, ImplicitlyDestructible].__del__is_trivial:
            return False
    return True


fn __to_ident(s: String) -> String:
    if s.startswith("--"):
        var fixed = s.replace("-", "_")
        return String(fixed[2:])
    elif s.startswith("-"):
        var fixed = s.replace("-", "_")
        return String(fixed[1:])

    var fixed = s.replace("-", "_")
    return fixed


fn __possible_idents[T: JsonDeserializable]() -> Dict[String, String]:
    """ """
    comptime metadata = T.opt_metadata()
    comptime field_names = struct_field_names[T]()
    var ret: Dict[String, String] = {}
    comptime for i in range(0, len(field_names)):
        comptime name = field_names[i]

        comptime opts = metadata.get(name)
        if opts:
            if opts.value().short_opt:
                if opts.value().short_opt.value() in ret:
                    abort(
                        "Duplicate key: " + opts.value().short_opt.value()
                    )
                ret[opts.value().short_opt.value()] = String(name)
            if opts.value().long_opt:
                if opts.value().long_opt.value() in ret:
                    abort(
                        "Duplicate key: " + opts.value().long_opt.value()
                    )
                ret[opts.value().long_opt.value()] = String(name)

        ret[__to_ident(name)] = String(name)
    return ret^


@always_inline
fn _default_deserialize[
    options: ParseOptions,
    //,
    T: _Base,
    is_array: Bool,
](mut p: Parser[options], out s: T) raises:
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

    comptime if is_array:
        # Assumes that args have been passed in in order of the struct
        comptime for i in range(field_count):
            ref field = __struct_field_ref(i, s)
            comptime TField = downcast[type_of(field), _Base]
            field = _deserialize_impl[TField](p)
    else:
        # Fill via key-value pairs

        # maybe an optimization since the InlineArray ctor uses a for loop
        # but according to the IR this will just inline the computed values
        var seen = materialize[InlineArray[Bool, field_count](fill=False)]()
        comptime type_metadata = downcast[T, JsonDeserializable].opt_metadata()
        var possible_idents = materialize[__possible_idents[
            downcast[T, JsonDeserializable]
        ]()]()

        var positionals: List[String] = []
        # while p.peek() != `}`:
        while not p.is_done():
            var candidate_ident = p.read_string()
            if candidate_ident== "--help" or candidate_ident== "-h":
                # TODO: need a "print_help[T]()" fn that can be called
                print("HELP")
            else:
                print(t"ident {candidate_ident}")

            var ident = possible_idents.get(__to_ident(candidate_ident))

            if not ident:
                # Actually might be positional argument
                # raise Error("Unexpected field: ", candidate_ident)
                positionals.append(candidate_ident)
                continue

            var matched = False
            comptime for i in range(field_count):
                comptime name = field_names[i]

                if ident.value() == name:
                    ref seen_i = seen.unsafe_get(i)


                    comptime if Bool(type_metadata.get(name)) and type_metadata.get(name).value().is_arg:
                        raise Error(name, "is a positional argument, not an option.")

                    
                    ref field = __struct_field_ref(i, s)
                    comptime TField = downcast[type_of(field), _Base]

                    # Special handling of bool fields, which are flags
                    comptime if __is_appendable[TField]():
                        # TODO: add the append_from_json method to the trait, default to explode if not a list
                        trait_downcast[JsonDeserializableAppendable](field).append_from_json(p)
                    elif _type_is_eq[TField, Bool]():
                        if seen_i:
                            raise Error("Duplicate key: ", name)
                        comptime if Bool(type_metadata.get(name)) and Bool(type_metadata.get(name).value().default_value):
                            # Invert whatever the supplied default was
                            comptime value = type_metadata.get(name).value().default_value.value()
                            var p = Parser([value])
                            field = downcast[TField, JsonDeserializable].from_json(p)
                            field = rebind[TField](not rebind[Bool](field))
                        else:
                            # Since the default for bool is False, invert it to true
                            field = rebind[TField](True)
                    else:
                        if seen_i:
                            raise Error("Duplicate key: ", name)
                        field = _deserialize_impl[TField](p)

                    seen_i = True
                    matched = True

            if not matched:
                raise Error("Unexpected field: ", candidate_ident)

            # p.skip_whitespace()
            # if p.peek() != `}`:
            #     p.expect(`,`)
        
        # Check for positional arguments
        if positionals:
            var pp = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingArguments)](positionals^)
            comptime for i in range(field_count):
                comptime metadata = type_metadata.get(field_names[i])
                if pp.is_done():
                    break

                comptime if Bool(metadata) and metadata.value().is_arg:
                    ref seen_i = seen.unsafe_get(i)
                    seen_i = True
                    ref field = __struct_field_ref(i, s)
                    comptime TField = downcast[type_of(field), _Base]
                    try:
                        field = _deserialize_impl[TField](pp)
                    except e:
                        raise Error(t"Can't parse positional argument {materialize[field_names[i]]()}: {e}")
                else:
                    print(metadata)

            if not pp.is_done():
                raise Error("Unexpected fields: ", pp.data)


        comptime for i in range(field_count):
            # We didn't find a key value pairing
            if not seen.unsafe_get(i):
                comptime metadata = downcast[
                    T, JsonDeserializable
                ].opt_metadata().get(field_names[i])

                # TODO: make issue for this?
                # Must wrap in bool to avoid incompatable type error
                comptime if Bool(metadata) and Bool(
                    metadata.value().default_value
                ):
                    # First try to get a default from the metadata
                    comptime default = metadata.value().default_value.value()
                    ref field = __struct_field_ref(i, s)
                    var p = Parser[ParseOptions(parsing_mode=ParseOptions.ParsingDefaults)]([default])
                    field = downcast[
                        type_of(field), JsonDeserializable
                    ].from_json(p)
                elif __is_optional[field_types[i]]():
                    # Turned off the Defaultable fallback
                    # or conforms_to(
                    #     field_types[i], Defaultable
                    # ):
                    # Then check if defaultable or optional
                    print("Using the Optional default")
                    ref field = __struct_field_ref(i, s)
                    field = downcast[type_of(field), Defaultable]()
                else:
                    # Explode
                    comptime name = field_names[i]
                    raise Error("Missing key: ", name)


fn _deserialize_impl[
    options: ParseOptions, //, T: _Base
](mut p: Parser[options], out s: T) raises:
    comptime assert is_struct_type[T](), non_struct_error

    comptime if conforms_to(T, JsonDeserializable):
        s = downcast[T, JsonDeserializable].from_json(p)
    else:
        s = _default_deserialize[T, False](p)


# ===============================================
# Primitives
# ===============================================


__extension String(JsonDeserializable):
    @staticmethod
    fn from_json[
        options: ParseOptions, //
    ](mut p: Parser[options], out s: Self) raises:
        s = p.read_string()

    @staticmethod
    fn deserialize_as_array() -> Bool:
        return False

    @staticmethod
    fn opt_metadata() -> Dict[String, OptHelp]:
        return {}


__extension Int(JsonDeserializable):

    fn from_json[
        options: ParseOptions, //
    ](mut p: Parser[options], out s: Self) raises:
        s = p.read_int()

    @staticmethod
    fn deserialize_as_array() -> Bool:
        return False

    @staticmethod
    fn opt_metadata() -> Dict[String, OptHelp]:
        return {}


__extension Bool(JsonDeserializable):

    @staticmethod
    fn from_json[
        options: ParseOptions, //
    ](mut p: Parser[options], out s: Self) raises:
        s = p.read_bool()

    @staticmethod
    fn deserialize_as_array() -> Bool:
        return False

    @staticmethod
    fn opt_metadata() -> Dict[String, OptHelp]:
        return {}


# __extension SIMD(JsonDeserializable):
#     @staticmethod
#     fn from_json[
#         options: ParseOptions, //
#     ](mut p: Parser[options], out s: Self) raises:
#         s = Self()

#         @parameter
#         @always_inline
#         fn parse_simd_element(
#             mut p: Parser[options],
#         ) raises -> Scalar[Self.dtype]:
#             comptime if Self.dtype.is_numeric():
#                 comptime if Self.dtype.is_floating_point():
#                     return p.expect_float[Self.dtype]()
#                 else:
#                     comptime if Self.dtype.is_signed():
#                         return p.expect_integer[Self.dtype]()
#                     else:
#                         return p.expect_unsigned_integer[Self.dtype]()
#             else:
#                 return Scalar[Self.dtype](p.expect_bool())

#         comptime if size > 1:
#             p.expect(`[`)

#         comptime for i in range(size):
#             s[i] = parse_simd_element(p)

#             comptime if i < size - 1:
#                 p.expect(`,`)

#         comptime if size > 1:
#             p.expect(`]`)

#     @staticmethod
#     fn deserialize_as_array() -> Bool:
#         return False


# __extension IntLiteral(JsonDeserializable):
#     @staticmethod
#     fn from_json[
#         options: ParseOptions, //
#     ](mut p: Parser[options], out s: Self) raises:
#         s = Self()
#         var i = p.expect_integer()
#         if i != s:
#             raise Error("Expected: ", s, ", Received: ", i)

#     @staticmethod
#     fn deserialize_as_array() -> Bool:
#         return False


# __extension FloatLiteral(JsonDeserializable):
#     @staticmethod
#     fn from_json[
#         options: ParseOptions, //
#     ](mut p: Parser[options], out s: Self) raises:
#         s = Self()
#         var f = p.expect_float()
#         if f != s:
#             raise Error("Expected: ", s, ", Received: ", f)

#     @staticmethod
#     fn deserialize_as_array() -> Bool:
#         return False


# # ===============================================
# # Pointers
# # ===============================================


# __extension ArcPointer(JsonDeserializable):
#     @staticmethod
#     fn from_json[
#         options: ParseOptions, //
#     ](mut p: Parser[options], out s: Self) raises:
#         s = Self(_deserialize_impl[downcast[Self.T, _Base]](p))

#     @staticmethod
#     fn deserialize_as_array() -> Bool:
#         return False


# __extension OwnedPointer(JsonDeserializable):
#     @staticmethod
#     fn from_json[
#         options: ParseOptions, //
#     ](mut p: Parser[options], out s: Self) raises:
#         s = rebind_var[Self](
#             OwnedPointer(_deserialize_impl[downcast[Self.T, _Base]](p))
#         )

#     @staticmethod
#     fn deserialize_as_array() -> Bool:
#         return False


# # ===============================================
# # Collections
# # ===============================================


# __extension Optional(JsonDeserializable):
#     @staticmethod
#     fn from_json[
#         options: ParseOptions, //
#     ](mut p: Parser[options], out s: Self) raises:
#         if p.peek() == `n`:
#             p.expect_null()
#             s = None
#         else:
#             s = Self(_deserialize_impl[downcast[Self.T, _Base]](p))

#     @staticmethod
#     fn deserialize_as_array() -> Bool:
#         return False


__extension List(JsonDeserializableAppendable):
    fn append_to(mut self, var value: Some[Copyable & _Base]):
        self.append(rebind_var[Self.T](value^))

    fn append_from_json[options: ParseOptions, //](mut self, mut p: Parser[options]) raises:
        var deser = _deserialize_impl[downcast[Self.T, _Base]](p) # _Base
        var value = trait_downcast_var[Copyable&_Base](deser^) # implicitly Self.T
        self.append_to(value^)

    @staticmethod
    fn from_json[
        options: ParseOptions, //
    ](mut p: Parser[options], out s: Self) raises:
        s = Self()
        
        comptime if options.parsing_mode == ParseOptions.ParsingArguments:
            # If we are argument parsing, consume all the values possible
            while not p.is_done():
                s.append(_deserialize_impl[downcast[Self.T, _Base]](p))
        elif options.parsing_mode == ParseOptions.ParsingOptions:
            # If we are still option parsing, lists will come as kv pairs still
            s.append(_deserialize_impl[downcast[Self.T, _Base]](p))
        elif options.parsing_mode == ParseOptions.ParsingDefaults:
            # Parsing a user defined default value, which will be a comma delimited string
            for v in p.read_string().split(","):
                var default_parser = Parser[options]([String(v)])
                s.append(_deserialize_impl[downcast[Self.T, _Base]](default_parser))
        else:
            raise Error(t"Unknown parse mode: {options.parsing_mode}")

    @staticmethod
    fn deserialize_as_array() -> Bool:
        return False

    @staticmethod
    fn opt_metadata() -> Dict[String, OptHelp]:
        return {}


# __extension Dict(JsonDeserializable):
#     @staticmethod
#     fn from_json[
#         options: ParseOptions, //
#     ](mut p: Parser[options], out s: Self) raises:
#         comptime assert (
#             _type_is_eq[Self.K, String]()
#             or get_base_type_name[Self.K]() == "LazyString"
#         ), "Dict must have string keys"
#         p.expect(`{`)
#         s = Self()

#         while p.peek() != `}`:
#             var ident = rebind_var[Self.K](
#                 _deserialize_impl[downcast[Self.K, _Base & Movable]](p)
#             )
#             p.expect(`:`)
#             s[ident^] = _deserialize_impl[downcast[Self.V, _Base]](p)
#             p.skip_whitespace()
#             if p.peek() != `}`:
#                 p.expect(`,`)
#         p.expect(`}`)

#     @staticmethod
#     fn deserialize_as_array() -> Bool:
#         return False


# __extension Tuple(JsonDeserializable):
#     @staticmethod
#     fn from_json[
#         options: ParseOptions, //
#     ](mut p: Parser[options], out s: Self) raises:
#         __mlir_op.`lit.ownership.mark_initialized`(__get_mvalue_as_litref(s))
#         p.expect(`[`)

#         comptime for i in range(Self.__len__()):
#             UnsafePointer(to=s[i]).init_pointee_move(
#                 _deserialize_impl[downcast[Self.element_types[i], _Base]](p)
#             )

#             if i < Self.__len__() - 1:
#                 p.expect(`,`)

#         p.expect(`]`)

#     @staticmethod
#     fn deserialize_as_array() -> Bool:
#         return False


# __extension InlineArray(JsonDeserializable):
#     @staticmethod
#     fn from_json[
#         options: ParseOptions, //
#     ](mut j: Parser[options], out s: Self) raises:
#         j.expect(`[`)
#         s = Self(uninitialized=True)

#         for i in range(size):
#             UnsafePointer(to=s[i]).init_pointee_move(
#                 _deserialize_impl[downcast[Self.ElementType, _Base]](j)
#             )

#             if i != size - 1:
#                 j.expect(`,`)

#         j.expect(`]`)

#     @staticmethod
#     fn deserialize_as_array() -> Bool:
#         return False


# __extension Set(JsonDeserializable):
#     @staticmethod
#     fn from_json[
#         options: ParseOptions, //
#     ](mut j: Parser[options], out s: Self) raises:
#         j.expect(`[`)
#         s = Self()

#         while j.peek() != `]`:
#             s.add(_deserialize_impl[downcast[Self.T, _Base]](j))
#             j.skip_whitespace()
#             if j.peek() != `]`:
#                 j.expect(`,`)
#         j.expect(`]`)

#     @staticmethod
#     fn deserialize_as_array() -> Bool:
#         return False
