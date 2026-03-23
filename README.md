# MojOpt

A Mojo library for parsing CLI args based on the Rust Structopt crate.

> [!WARNING]  
> This library is under active development.

## Synopsis

`MojOpt` is a fully featured CLI option parser that uses struct definitions to parse the CLI options.


## Example

```mojo

from mojopt.command import MojOpt, Commandable
from mojopt.default import reflection_default
from mojopt.deserialize import MojOptDeserializable, Opt
from mojopt.parser import Parser

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

- TODO: update readme example
- TODO: add ci
- TODO: update everythign to use reexported types
- TODO: use docstrings / minimize imports
