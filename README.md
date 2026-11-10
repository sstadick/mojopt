# mojopt

Define command-line options, positional arguments, and subcommands with Mojo
structs. MojOpt parses typed values and generates help from your field descriptions.

## Install

This checkout requires **Mojo 1.2.0** from the stable
`https://conda.modular.com/max` channel.

```sh
pixi add mojopt
```

To use the source package, pin a compatible revision for reproducible builds:

```sh
pixi add --git https://github.com/sstadick/mojopt.git mojopt
```

## Get started

```mojo
from mojopt.command import Commandable, MojOpt
from mojopt.default import reflection_default
from mojopt.deserialize import Opt


@fieldwise_init
struct Options(Commandable, Defaultable):
    var display_name: Opt[String, long="name", short="n", help="Name to display"]
    var count: Opt[Int, short="c", default_value=["1"], help="Number of copies"]
    var verbose: Opt[Bool, short="v", defaultable=True, help="Show extra output"]
    var input: Opt[String, is_arg=True, help="Input file"]

    def __init__(out self):
        self = reflection_default[Self]()

    def run(self) raises:
        print(self.input.value, self.display_name.value, self.count.value, self.verbose.value)
        print("name supplied:", self.display_name.provided)


def main() raises:
    MojOpt[Options]().run()
```

```sh
mojo run main.mojo input.txt --name Ada --count 3 --verbose
mojo run main.mojo input.txt -nAda -vc3
mojo run main.mojo --help
```

`MojOpt.run()` prints help and exits successfully for `--help` or `-h`; parse
errors exit with status 2. To handle results yourself, use
`Parser.parse[Options](args)` from `mojopt.parser` and catch `MojOptErr` from
`mojopt.error`. Its alternatives are `Error` and `DisplayHelp`.

## Describe fields

| Declaration | Meaning |
| --- | --- |
| `Opt[T, help="..."]` | A typed field with help text; read its result through `.value`. |
| `short="n"` | Add `-n` as a short option. Use single-character names for bundles. |
| `long="first-name"` | Set the displayed long name. The original field name also remains accepted. |
| `default_value=["1"]` | Values used when the field is omitted. |
| `defaultable=True` | Use `T()` when omitted. `T` must implement `Defaultable`. |
| `is_arg=True` | Consume a positional argument, in declaration order. |

Fields without `default_value` or `defaultable=True` are required. Bare fields
such as `var count: Int` also work; bare `Optional[T]` fields may be omitted.
Struct initializer values do not satisfy required fields. If both default
settings are present, `default_value` takes priority.

Field names display with underscores replaced by hyphens. Both `--first-name`
and `--first_name` are accepted. Enum values, unlike option names, are exact.

## Supply values

- `--name Ada`, `--name=Ada`, `-n Ada`, and `-nAda` supply a value.
- Long options split at the first `=`: `--name=a=b` supplies `a=b`, and
  `--name=` supplies an empty string.
- Short bundles scan left to right. In `-vqc3`, flags `v` and `q` become true,
  and `c` consumes `3`. Without attached text, a value option consumes the next
  token. An attached `=` is literal: `-n=Ada` supplies `=Ada`.
- Bare boolean flags set true, including flags whose default is true.
  `--verbose=false` and `--verbose=true` accept only these lowercase spellings.
  A bare flag does not consume the next token.
- Repeated scalar options use the last value. Repeated flags are allowed.
- A standalone `--` ends option recognition. Tokens after it are positional.
  A value option consuming `--` or `--help` treats it as a literal value.
- Help takes effect when encountered; an earlier unknown option or invalid
  option value remains an error.

`Opt.provided` is true only when the current parse explicitly supplied the
field. Explicit false, zero, empty strings, and values equal to a default all
count. Omitted or default-derived fields have `provided=False`.

## Collections and positional arguments

`Opt[List[String], short="I", defaultable=True]` accepts repeated occurrences:

```sh
program -Isrc --include="test files" --include=src -I ""
```

The result is `["src", "test files", "src", ""]`. The first explicit occurrence
replaces any defaults; later occurrences append. Lists retain order and
duplicates. Sets retain their normal uniqueness semantics. These containers
also support other deserializable element types.

An `Opt[List[T], is_arg=True]` collects remaining positionals. Only one such
unbounded positional container is allowed per command. Fixed-size `Array`
and `Tuple` positional fields, including nested containers, are also supported.

## Enum choices

Use a payload-free enum for typed choices:

```mojo
__enum Format(ImplicitlyCopyable):
    case json
    case plain_text
    case CSV
```

Declare a field as `Opt[Format, short="f", default_value=["json"]]` and initialize
it with `self.format = {Format.json}` in your struct's initializer.
`--format=plain_text`, `--format CSV`, and `-fjson` return a `Format` in `.value`.
Help and invalid-value errors list the same case-sensitive choices. `csv`,
`plain-text`, and numeric indices are not accepted. Enum options may be
repeated in a `List`, or used as positional arguments. Payload variants are
not supported.

See the complete [options example](examples/options.mojo).

## Custom types and subcommands

Implement `MojOptDeserializable.from_opts` to consume values with
`Parser.read_string()`, `read_int()`, `read_float()`, or `read_bool()`.
These readers raise on missing or invalid values. Custom parsers may consume
multiple tokens; attached values supply their first token. Nested structs
can also be parsed from their own named fields.

Pass multiple `Commandable` types to `MojOpt[CommandA, CommandB]` to dispatch
on a subcommand name. Names default to struct names and may be overridden
with `comptime name = "..."`. A single command works with or without its name.
See [subcommands](examples/subcommands.mojo) and [getting started](examples/getting_started.mojo).

Generated help uses GNU-style `--name=VALUE` syntax for value options, no value
placeholder for flags, and `...` for repeatable options. For zsh completion:

```zsh
autoload -Uz compinit
compinit
compdef _gnu_generic /path/to/program
```

## Attributions

- Inspired by [structopt](https://github.com/TeXitoi/structopt).
- Reflection examples in [EmberJson](https://github.com/bgreni/EmberJson) by @bgreni.
