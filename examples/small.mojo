from mojopt.command import MojOpt, Commandable
from mojopt.default import reflection_default
from mojopt.deserialize import Opt


@fieldwise_init
struct Example(Commandable, Defaultable, Movable, Writable):
    var example: Opt[String, help="Just an example string", short="e", default_value=["foobar"]]
    var number: Opt[Int, help="Just a number", long="num", short="n", defaultable=True]

    def __init__(out self):
        self = reflection_default[Self]()

    @staticmethod
    def description() -> String:
        return "Just an example program."

    def run(self) raises:
        print(self)


def main() raises:
    MojOpt[Example]().run()
