
from stoke.deserialize import JsonDeserializable, OptHelp
from stoke.parser import Parser, ParseOptions
from stoke import Stoke


@fieldwise_init
struct GetLanguages(JsonDeserializable, Defaultable, Writable):
    var first_name: String
    var last_name: String
    var languages: List[String]

    # TODO: contribute default implementation to Defaultable that works like Rust Default
    # We shouldn't have to fill this out by hand.
    fn __init__(out self):
        self.first_name = ""
        self.last_name = ""
        self.languages = []
    
    @staticmethod
    def opt_metadata() -> Dict[String, OptHelp]:
        return {
            "first_name": OptHelp(help_msg="First Name"),
            "last_name": OptHelp(help_msg="Last Name"),
            "languages": OptHelp(help_msg="Languages spoken", is_arg=True),
        }

@fieldwise_init
struct GetSports(JsonDeserializable, Defaultable, Writable):
    var first_name: String
    var last_name: String
    var sports: List[String]

    # TODO: contribute default implementation to Defaultable that works like Rust Default
    # We shouldn't have to fill this out by hand.
    fn __init__(out self):
        self.first_name = ""
        self.last_name = ""
        self.sports= []
    
    @staticmethod
    fn opt_metadata() -> Dict[String, OptHelp]:
        return {
            "first_name": OptHelp(help_msg="First Name"),
            "last_name": OptHelp(help_msg="Last Name"),
            "sports": OptHelp(help_msg="Sports played", is_arg=True),
        }
    
@fieldwise_init
struct Main(JsonDeserializable, Defaultable, Writable):
    var example: String
    var number: Int

    fn __init__(out self):
        self.example = ""
        self.number = 0


def stoke_get_languages(var argv: List[String]):
    var args = Parser.parse[GetLanguages](argv^)
    print(args)

def stoke_get_sports(var argv: List[String]):
    var args = Parser.parse[GetSports](argv^)
    print(args)

def stoke_main(var argv: List[String]):
    var args = Parser.parse[Main](argv^)
    print(args)

def main() raises:
    Stoke.register_commands[__functions_in_module()]().run()
