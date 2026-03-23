# mojopt

A Mojo library for parsing command line options by defining a struct.

> [!WARNING]  
> This library is under active development.

## Synopsis

`mojopt` is a CLI option parser that uses struct definitions to parse the CLI options.

## Install

From Modular Community:

```bash
# Not yet published
# pixi add mojopt && pixi install
```

From source:

```bash
pixi add --git "https://github.com/sstadick/mojopt.git" mojopt && pixi install
```

## Example

An example project is set up [here](https://github.com/sstadick/mojopt-demo).

## Simple

```mojo
from mojopt.command import MojOpt, Commandable
from mojopt.default import reflection_default
from mojopt.deserialize import Opt


@fieldwise_init
struct Example(Commandable, Defaultable, Movable, Writable):
    var example: Opt[String, help="Just an example string", short="e", default_value=["foobar"]]
    var number: Opt[Int, help="Just a number", long="num", short="n", defaultable=True]

    def __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    def description() -> String:
        return "Just an example program."

    def run(self) raises:
        print(self)


def main() raises:
    MojOpt[Example]().run()
```

### Getting Started

```mojo
from mojopt.command import Commandable, MojOpt
from mojopt.default import reflection_default
from mojopt.deserialize import MojOptDeserializable, Opt


@fieldwise_init
struct Args(Commandable, Defaultable, MojOptDeserializable, Writable):
    comptime name = "args"
    """Commandables default to the struct Name, but that can be overridden."""

    var first_name: Opt[String, help="The users first name", long="first-name", short="f"]
    """Opt is a translucent type that supplies metadata to the parser.

    At compile time all options are checked to ensure no conflicting long/short flags, and
    all defaults are check to make sure they are valid.
    """

    var last_name: String
    """You don't have to use Opt, though.

    Bare options work just fine, but don't have a help description.
    """

    var special_number: Opt[
        Int, help="Super special number.", long="special", short="s", default_value=["42"]
    ]
    """Default values can be supplied via the `default_value` parameter.

    You can also set `defaultable=True` to use the default value of the type instead.
    If both are set, the `default_value` takes priority.

    `default_value` works for multi-opts as well.
    For example, if this was a `List[Int]` instead, the default could be `["4", "2"]`.
    On the cli that would be passed by setting the option twice `-s 4 -s 2`.
    """

    var languages: Opt[List[String], help="The languages the user speaks", is_arg=True]
    """Positional args are supported.

    Only one "fully consuming" positional arg is allowed per command.
    Additionally, fixed size positional arguments are supported such as Tuple and InlineArray.
    """

    def __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    def description() -> String:
        return """A small example program.
        
        This program demonstrates how to use the Opt type, as well as Commandable.
        """

    def run(self) raises:
        print(self)
        # Note that for Opt types you must access the inner type via `.value`
        print(self.first_name.value)


def main() raises:
    # Commandable structs can be passed to MojoOpt, which will dispatch based on the first argument.
    # If there is only one command, that is treated as main, but will also still work as a subcomand.
    # i.e. `./getting_started args --help` and `./getting_started --help` both work here
    MojOpt[Args]().run()
```


### Subcommands

```mojo
from mojopt.command import MojOpt, Commandable
from mojopt.default import reflection_default
from mojopt.deserialize import MojOptDeserializable, Opt


@fieldwise_init
struct GetLanguages(Commandable, Defaultable, MojOptDeserializable, Writable):
    var first_name: Opt[String, help="First name", defaultable=True]
    var last_name: Opt[String, help="Last name", default_value=["Mojo"]]
    var languages: Opt[List[String], is_arg=True, help="Languages spoken"]

    def __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    def description() -> String:
        return "List the languages spoken."

    def run(self) raises:
        print(self)


@fieldwise_init
struct GetSports(Commandable, Defaultable, MojOptDeserializable, Writable):
    var first_name: Opt[String, help="First name", long="firstname", short="f"]
    var last_name: Opt[String, help="Last name", long="lastname", short="l"]
    var sports: Opt[List[String], is_arg=True, help="Sports played"]

    def __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    def description() -> String:
        return "List the sports played."

    def run(self) raises:
        print(self)


@fieldwise_init
struct Example(Commandable, Defaultable, MojOptDeserializable, Writable):
    var example: String
    var number: Int

    def __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    def description() -> String:
        return "Options and args done't have to be Opts!"

    def run(self) raises:
        print(self)


def main() raises:
    var toolkit_description = """A contrived example of using multiple subcommands.

    Note that if just one subcommand is given it will be treated as a "main" and can be
    launched either by running the program with no subcommand specified, or by specifying
    subcommand name."""
    MojOpt[GetLanguages, GetSports, Example]().run(toolkit_description=toolkit_description)
```

For more examples see the [examples](./examples).

## Defining `MojOptDeserialize` for custom types

This works!

- TODO: write some docs on this. 

## Known issues and todos

- TODO: more docs

## Attributions

- Design for this was entirely inspired by [structopt](https://github.com/TeXitoi/structopt)
- The path for much of this reflection work was blazed by @bgreni in [EmberJson](https://github.com/bgreni/EmberJson/tree/main)
