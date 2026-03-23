from mojopt.command import Commandable, MojOpt
from mojopt.default import reflection_default
from mojopt.deserialize import MojOptDeserializable, Opt


@fieldwise_init
struct Args(Commandable, Defaultable, MojOptDeserializable, Writable):
    var first_name: Opt[String, help="The users first name", long="first-name", short="f"]
    var last_name: String
    var nested: Opt[Nested, help="A nested struct, what could go wrong?"]
    var languages: Opt[List[String], help="The languages the user speaks", is_arg=True]

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
struct Nested(Defaultable, MojOptDeserializable, Writable):
    """Nested structs are parsed the same way as outer structs.
    
    The only requirement is that they follow the outer opt immediately.
    In this example, the opts might look like:

    ```
    prog --first-name John \
         --nested \
            --inner-mind peace \
            --outer-body 42 \
          --last-name Doe \
          English Spanish
    ```
    """

    var inner_mind: Opt[String, help="Inner sanctum"]
    var outer_body: Opt[Int, help="Outer fortresss"]

    fn __init__(out self):
        self = reflection_default[Self]()


def main() raises:
    MojOpt[Args]().run()


# Note, you could aso run this like:
# from mojopt.parser import Parser
# def main() raises:
#     var args = Parser.parse[Args]()
#     print(args)
