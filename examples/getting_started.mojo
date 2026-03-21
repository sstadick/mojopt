# from mojopt import reflection_default, MojOptDeserializable, Opt, LoadExts
from mojopt.command import MojOpt, Commandable
from mojopt.default import reflection_default
from mojopt.deserialize import MojOptDeserializable, Opt, LoadExts
from mojopt.parser import Parser

# Needed to force the loading of extensions
# comptime Exts = LoadExts().FullConformance

@fieldwise_init
struct Args(MojOptDeserializable, Defaultable, Writable, Commandable):
    var first_name: Opt[String, help="The users first name", long="first-name", short="f"]
    var last_name: String
    # var languages: Opt[List[String], help="The languages the user speaks", is_arg=True]
    var numbers: Opt[List[Int], help="The languages the user speaks", is_arg=True]
    var nested: Opt[Nested, help="A nested struct, what could go wrong?"]
    var nested_bare: Nested
    var nested2: Opt[Nested2, help="A nested struct, what could go wrong?"]
    var nested2_bare: Nested2

    fn __init__(out self):
        self = reflection_default[Self]()
    
    @staticmethod
    fn description() -> String:
        return """A small example program.
        
        This program demonstrates how to use the Opt type, as well as Commandable.
        """
    
    fn run(self) raises:
        print(self)
    
@fieldwise_init
struct Nested(MojOptDeserializable, Defaultable, Writable):
    var inner_mind: Opt[String, help="Inner sanctum"]
    var outer_body: Opt[Int, help="Outer fortresss"]

    fn __init__(out self):
        self = reflection_default[Self]()

@fieldwise_init
struct Nested2(Movable, Defaultable, Writable):
    var inner_mind: Opt[String, help="Inner sanctum"]
    var outer_body: Opt[Int, help="Outer fortresss"]

    fn __init__(out self):
        self = reflection_default[Self]()

def main() raises:
    MojOpt[Args]().run()

# Note, you could aso run this like:
# def main() raises:
#     var args = Parser.parse[Args]()
#     print(args)
