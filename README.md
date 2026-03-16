# MojOpt

A Mojo library for parsing CLI args based on the Rust Structopt crate.

> [!WARNING]  
> This library is under active development. It's entirely predicated on something that is probably a compiler bug.
> Use at your own risk.

## Synopsis

`MojOpt` is a fully featured CLI option parser that uses struct definitions to parse the CLI options.

### The hack

Metadata about options can optionally be supplied via the translucent type `Opt`, which allows for specifying `help`, `long`, `short`, etc.
`Opt` works because `MojOptDeserializable` is implemented for base types via conforming `__extension`s.
Extensions are not a fully baked language feature yet.
To the get implemented methods to import, you hoave to evalutate something that uses them at `comptime`, which is what the `LoadExts().FullConformance` hack is doing.
As mentioned above, this is likely a leaky compiler bug.

An earlier iteration of `MojOpt` supplied the `Opts` via a method called `get_metadata` on the `MojOptDeserializable` trait.
It returned a `Dict[String, Opt]` where the keys were the field names.
This worked but had the downside of defining the metadata away from the struct field definitions.
If the bug above is fixed such that extensions can't be imported, this library will fall back to the comptime dict metadata.


## Example

```mojo

from mojopt.command import MojOpt, Commandable
from mojopt.default import reflection_default
from mojopt.deserialize import MojOptDeserializable, Opt, LoadExts
from mojopt.parser import Parser


# Needed to force loading Exts
comptime Ext = LoadExts().FullConformance

@fieldwise_init
struct GetLanguages(MojOptDeserializable, Defaultable, Writable, Commandable):
    var first_name: Opt[String, help="First name"]
    var last_name: Opt[String, help="Last name"]
    var languages: Opt[List[String], is_arg=True, help="Languages spoken"]

    fn __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    fn description() -> String:
        return "List the languages spoken."

    def run(self) raises:
        print(self)

@fieldwise_init
struct GetSports(MojOptDeserializable, Defaultable, Writable, Commandable):
    var first_name: Opt[String, help="First name", long="blarg-name"]
    var last_name: Opt[String, help="Last name"]
    var sports: Opt[List[String], is_arg=True, help="Sports played"]

    fn __init__(out self):
        self = reflection_default[Self]()
    
    @staticmethod
    fn description() -> String:
        return "List the sports played."
    
    def run(self) raises:
        print(self)
    
@fieldwise_init
struct Example(MojOptDeserializable, Defaultable, Writable, Commandable):
    var example: Opt[String]
    var number: Opt[Int]

    fn __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    fn description() -> String:
        return "Just an example."

    def run(self) raises:
        print(self)

def main() raises:
    var toolkit_description = """A contrived example of using multiple subcommands.

    Note that if just one subcommand is given it will be treated as a "main" and can be
    launched either by running the program with no subcommand specified, or by specifying
    subcommand name.
    """
    MojOpt[GetLanguages, GetSports, Example]().run(toolkit_description=toolkit_description)

```

## Defining `MojOptDeserialize` for custom types

Works, TODO - write some docs on this. 

## Known issues and todos

- TODO: Implement extensions for more base types