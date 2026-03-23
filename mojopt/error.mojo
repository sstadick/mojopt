from std.utils import Variant
from std.sys import exit

comptime MojOptErr = Variant[Error, DisplayHelp]


@fieldwise_init
struct DisplayHelp(Movable, Writable):
    var help: String


@always_inline
fn default_handling(e: MojOptErr):
    if e.isa[DisplayHelp]():
        print(e[DisplayHelp].help)
        exit(0)
    else:
        print("error:", e)
        print("\nFor more information, try '--help'.")
        exit(2)
