from std.sys import argv, exit

from mojopt.deserialize import MojOptDeserializable
from mojopt.parser import Parser
from mojopt.error import default_handling

# TODO: Parser should take a slice
# TODO: convert from PascalCase to kebab-case for subcommands?


trait Commandable(MojOptDeserializable):
    comptime name: String = String(reflect[Self]().base_name())

    def run(self) raises:
        ...


struct MojOpt[*CommandTypes: Commandable](Movable):
    var argv: List[String]

    def __init__(out self):
        # TODO: probably hang onto the binary name later
        comptime assert (
            len(Self.CommandTypes) > 0
        ), "Must pass in at least one Commandable type to MojOpt."
        self.argv = [String(arg) for arg in argv()[1:]]

    def __init__(out self, var argv: List[String]):
        comptime assert (
            len(Self.CommandTypes) > 0
        ), "Must pass in at least one Commandable type to MojOpt."
        self.argv = argv^

    def run(self, toolkit_description: String = "") raises:
        # Single Command used to build MojOpt, treat is as "main" and allow it to work
        # with our without spelling out the subcommand.
        comptime if len(Self.CommandTypes) == 1:
            if len(self.argv) > 0 and Self.CommandTypes[0].name == self.argv[0]:
                try:
                    var args = Parser.parse[Self.CommandTypes[0]](List(self.argv[1:]))
                    args.run()
                except e:
                    default_handling(e)
            else:
                try:
                    var args = Parser.parse[Self.CommandTypes[0]](List(self.argv))
                    args.run()
                except e:
                    default_handling(e)
            return

        # Test each command to see if it matches.
        comptime for i in range(len(Self.CommandTypes)):
            if len(self.argv) > 0 and Self.CommandTypes[i].name == self.argv[0]:
                try:
                    var args = Parser.parse[Self.CommandTypes[i]](List(self.argv[1:]))
                    args.run()
                    break
                except e:
                    default_handling(e)
        else:
            if len(self.argv) > 0 and (self.argv[0] == "--help" or self.argv[0] == "-h"):
                if toolkit_description.byte_length() > 0:
                    print("\n".join([line.lstrip() for line in toolkit_description.splitlines()]))
                print("\nCommands:")
                comptime for i in range(len(Self.CommandTypes)):
                    print(t"  {Self.CommandTypes[i].name}:")
                    print(
                        "\n".join(
                            [
                                String(t"          {line.lstrip()}")
                                for line in Self.CommandTypes[i].description().splitlines()
                            ]
                        )
                    )
                exit(0)
            elif len(self.argv) > 0:
                print(t"No matching command for {self.argv[0]}")
                print()
                print("\nFor more information, try '--help'.")
                exit(2)
            else:
                print(t"No command specified.")
                print()
                print("\nFor more information, try '--help'.")
                exit(2)
