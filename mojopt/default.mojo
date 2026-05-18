from std.builtin.constrained import _constrained_field_conforms_to


@always_inline
def reflection_default[T: Defaultable & Movable](out this: T):
    """Get a default instance of type `T` if all members conform to
    `Defaultable & Movable`.
    """
    __mlir_op.`lit.ownership.mark_initialized`(__get_mvalue_as_litref(this))
    comptime r = reflect[T]()
    comptime names = r.field_names()
    comptime types = r.field_types()
    comptime for i in range(names.size):
        comptime FieldType = types[i]
        _constrained_field_conforms_to[
            conforms_to(FieldType, Defaultable & Movable),
            Parent=T,
            FieldIndex=i,
            ParentConformsTo="Defaultable & Movable",
        ]()
        ref field = trait_downcast[Movable & Defaultable](r.field_ref[i](this))
        UnsafePointer(to=field).init_pointee_move(type_of(field)())
