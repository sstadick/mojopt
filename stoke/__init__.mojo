from std.reflection import get_function_name, get_type_name
from std.sys import argv
from std.sys.intrinsics import _type_is_eq

from stoke.deserialize import JsonDeserializable


@fieldwise_init
struct _StokeCommand(Copyable):
    """A Stoke command to run."""
    comptime fn_type = fn(var List[String]) raises

    var cmd_fn: Self.fn_type
    var name: String
    var cmd_name: String

    fn __init__(out self, cmd_fn: Self.fn_type, name: String):
        self.cmd_fn = cmd_fn
        self.name = name
        self.cmd_name = self.name[len("stoke_"):].replace("_", "-")

struct Stoke(Movable):
    # https://github.com/modular/modular/blob/2e6b98d33b02b91366b5fb79141c528473c6903c/mojo/stdlib/std/testing/suite.mojo#L377
    """"""
    var commands: List[_StokeCommand]
    var argv: List[String]

    fn __init__(out self):
        self.commands = []
        # TODO: probably hand onto the binary name later
        self.argv = [String(arg) for arg in argv()[1:]]

    fn __init__(out self, var argv: List[String]):
        self.commands = []
        self.argv = argv^

    fn command[f: _StokeCommand.fn_type](mut self):
        """Registers a command."""
        self.commands.append(_StokeCommand(f, get_function_name[f]()))
    
    @staticmethod
    def register_commands[stoke_funcs: Tuple]() raises -> Self:
        var opts = Stoke()
        opts.launcher[stoke_funcs]()
        return opts^

    @staticmethod
    def register_commands[stoke_funcs: Tuple](var args: List[String]) raises -> Self:
        var opts = Stoke(args^)
        opts.launcher[stoke_funcs]()
        return opts^

    def launcher[stoke_funcs: Tuple](mut self) raises:
        # https://github.com/modular/modular/blob/2e6b98d33b02b91366b5fb79141c528473c6903c/mojo/stdlib/std/testing/suite.mojo#L450
        comptime for idx in range(len(stoke_funcs)):
            comptime stoke_func = stoke_funcs[idx]

            comptime if get_function_name[stoke_func]().startswith("stoke_"):
                comptime if _type_is_eq[type_of(stoke_func), _StokeCommand.fn_type]():
                    self.command[rebind[_StokeCommand.fn_type](stoke_func)]()
                else:
                    raise Error(
                        "test function '",
                        get_function_name[stoke_func](),
                        "' has nonconforming signature: ",
                        get_type_name[type_of(stoke_func)]()
                    )
            else:
                print("not stoke fn")
        # TODO: wire up with sys args to get subcommaond to run, also fix the subcommand names
    
    def run(self) raises:
        var cmd_idx, is_main = self.select_command()
        if is_main:
            self.commands[cmd_idx].cmd_fn(List(self.argv))
        else:
            self.commands[cmd_idx].cmd_fn(List(self.argv[1:]))

    
    def select_command(read self) raises -> Tuple[Int, Bool]:
        if len(self.argv) == 0:
            raise Error("No arguments passed in")
        
        var main_idx: Optional[Int] = None

        for i in range(0, len(self.commands)):
            if self.commands[i].cmd_name == self.argv[0]:
                return i, False
            elif self.commands[i].cmd_name == "main":
                main_idx = i
        
        if main_idx:
            return main_idx.value(), True

        raise Error(t"No matching command for {self.argv[0]}")
