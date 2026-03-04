from sys import argv

struct ParseOptions(Equatable, TrivialRegisterPassable):
    fn __init__(out self):
        return

struct Parser[options: ParseOptions = ParseOptions()]:
    var cursor: Int
    var data: List[StaticString]

    def __init__(out self):
        self.cursor = 0
        self.data = List(argv())
    
    def __init__(out self, var args: List[StaticString]):
        self.cursor = 0
        self.data = args^
    
    def is_done(read self) -> Bool:
        return self.cursor == len(self.data)
    
    def _get_next(mut self) -> StaticString:
        debug_assert(self.cursor < len(self.data), "Parser cursor has gone past end of data.")
        var value = self.data[self.cursor]
        self.cursor += 1
        return value
    
    def read_string(mut self) -> StaticString:
        # TODO: return ref
        return self._get_next()
    
    def read_bool(mut self) raises -> Bool:
        var value = self._get_next().lower()
        if value == "true" or value == "t":
            return True
        elif value == "false" or value == "f":
            return False
        else:
            raise Error("Expected bool, got: " + value)
        
    def read_int(mut self) raises -> Int:
        var value = self._get_next()
        return atol(value)
    
    @always_inline
    @classmethod
    def mark_initialized(s: Self):
        __mlir_op.`lit.ownership.mark_initialized`(__get_mvalue_as_litref(s))
