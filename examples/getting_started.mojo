from mojopt.command import Commandable, MojOpt
from mojopt.default import reflection_default
from mojopt.deserialize import MojOptDeserializable, Opt


@fieldwise_init
struct Args(Commandable, Defaultable, MojOptDeserializable, Writable):
    comptime name = "args"
    """Commandables default to the struct Name, but that can be overridden."""

    var first_name: Opt[String, help="The users first name", long="first-name", short="f"]
    """Opt is a translucent type that supplies metadata to the parser."""

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

    fn __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    fn description() -> String:
        return """A small example program.
        
        This program demonstrates how to use the Opt type, as well as Commandable.
        """

    fn run(self) raises:
        print(self)
        # Note that for Opt types you must access the inner type via `.value`
        print(self.first_name.value)


def main() raises:
    # Commandable structs can be passed to MojoOpt, which will dispatch based on the first argument.
    # If there is only one command, that is treated as main, but will also still work as a subcomand.
    # i.e. `./getting_started args --help` and `./getting_started --help` both work here
    MojOpt[Args]().run()
