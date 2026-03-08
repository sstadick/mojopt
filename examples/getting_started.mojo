from stoke.deserialize import JsonDeserializable, OptHelp
from stoke.parser import Parser, ParseOptions
from stoke import Stoke


@fieldwise_init
struct Args(JsonDeserializable, Defaultable, Writable):
    comptime blarg: String = "foo"
    var first_name: String
    var last_name: String
    var languages: List[String]

    # TODO: contribute default implementation to Defaultable that works like Rust Default
    # We shouldn't have to fill this out by hand.
    fn __init__(out self):
        self.first_name = ""
        self.last_name = ""
        self.languages = []
    
    # TODO: until we can reflect on comptime struct members, or have decorators of some sort / access to doc metadata, this is how we have to define thise
    # also until associated consts work through extensions.
    @staticmethod
    fn opt_metadata() -> Dict[String, OptHelp]:
        return {
            "first_name": OptHelp(help_msg="First Name"),
            "last_name": OptHelp(help_msg="Last Name"),
            "languages": OptHelp(help_msg="Languages spoken", is_arg=True),
        }


def stoke_main(var argv: List[String]):
    var args = Parser.parse[Args](argv^)
    print(args)

def main() raises:
    Stoke.register_commands[__functions_in_module()]().run()

# Note, you could aso run this like:
# def main() raises:
#     var args = Parser.parse[Args]()
#     print(args)