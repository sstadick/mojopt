from mojopt.command import Commandable, MojOpt
from mojopt.deserialize import Opt


__enum Format(ImplicitlyCopyable):
    case json
    case plain_text
    case CSV


@fieldwise_init
struct Options(Commandable, Defaultable):
    var display_name: Opt[String, long="name", short="n", help="Name to display"]
    var count: Opt[Int, short="c", default_value=["1"], help="Number of copies"]
    var verbose: Opt[Bool, short="v", defaultable=True, help="Show extra output"]
    var format: Opt[Format, short="f", default_value=["json"], help="Output format"]
    var include: Opt[List[String], short="I", defaultable=True, help="Search directory"]
    var input: Opt[String, is_arg=True, help="Input file"]

    def __init__(out self):
        self.display_name = {""}
        self.count = {0}
        self.verbose = {False}
        self.format = {Format.json}
        self.include = {[]}
        self.input = {""}

    @staticmethod
    def description() -> String:
        return "Display command-line settings."

    def run(self) raises:
        print(self.input.value, self.display_name.value, self.count.value, self.verbose.value)
        print(self.include.value)
        print("name supplied:", self.display_name.provided)


def main() raises:
    MojOpt[Options]().run()
