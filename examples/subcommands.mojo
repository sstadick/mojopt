from mojopt.command import MojOpt, Commandable
from mojopt.default import reflection_default
from mojopt.deserialize import MojOptDeserializable, Opt
from mojopt.parser import Parser


@fieldwise_init
struct GetLanguages(Commandable, Defaultable, MojOptDeserializable, Writable):
    var first_name: Opt[String, help="First name", defaultable=True]
    var last_name: Opt[String, help="Last name", default_value=["Mojo"]]
    var languages: Opt[List[String], is_arg=True, help="Languages spoken"]

    fn __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    fn description() -> String:
        return "List the languages spoken."

    def run(self) raises:
        print(self)


@fieldwise_init
struct GetSports(Commandable, Defaultable, MojOptDeserializable, Writable):
    var first_name: Opt[String, help="First name", long="firstname", short="f"]
    var last_name: Opt[String, help="Last name", long="lastname", short="l"]
    var sports: Opt[List[String], is_arg=True, help="Sports played"]

    fn __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    fn description() -> String:
        return "List the sports played."

    def run(self) raises:
        print(self)


@fieldwise_init
struct Example(Commandable, Defaultable, MojOptDeserializable, Writable):
    var example: String
    var number: Int

    fn __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    fn description() -> String:
        return "Options and args done't have to be Opts!"

    def run(self) raises:
        print(self)


def main() raises:
    var toolkit_description = """A contrived example of using multiple subcommands.

    Note that if just one subcommand is given it will be treated as a "main" and can be
    launched either by running the program with no subcommand specified, or by specifying
    subcommand name."""
    MojOpt[GetLanguages, GetSports, Example]().run(toolkit_description=toolkit_description)
