from mojopt.deserialize import MojOptDeserializable, Optable, _Base, __is_opt, __to_display_name

from std.builtin.rebind import downcast


def get_help[T: _Base, indent_level: Int = 1]() -> String:
    comptime r = reflect[T]()
    comptime field_names = r.field_names()
    comptime field_types = r.field_types()

    var options: List[String] = []
    var arguments: List[String] = []
    var description: String
    comptime if conforms_to(T, MojOptDeserializable) and not __is_opt[T]():
        description = "\n".join(
            [line.lstrip() for line in downcast[T, MojOptDeserializable].description().splitlines()]
        )
    else:
        description = ""

    comptime for i in range(0, len(field_names)):
        comptime field_type = field_types[i]
        comptime field_name = field_names[i]

        comptime if not reflect[field_type]().is_struct():
            continue

        comptime if not __is_opt[T]():
            comptime if conforms_to(field_type, Optable):
                comptime optlike = downcast[field_types[i], Optable]
                comptime short_name = String(
                    t"-{optlike.opt_short.value()}, "
                ) if optlike.opt_short else String("")
                comptime long_name = String(
                    t"{optlike.opt_long.value()}"
                ) if optlike.opt_long else String(t"{__to_display_name(field_name)}")
                # TODO: with parametric traits this would be a lot better
                # Relying on Opt implementing Writable to transparently show Opt.T
                comptime default = (
                    String(
                        t" [default: `{' '.join(optlike.opt_default_value.value())}`]"
                    ) if optlike.opt_default_value else String(
                        t" [default: `{downcast[field_type, Defaultable & Writable]()}`]"
                    ) if optlike.opt_defaultable
                    and conforms_to(field_type, Writable) else String(
                        " [default: `<default_not_writable>`]"
                    ) if optlike.opt_defaultable
                    and not conforms_to(field_type, Writable) else String(" [Required]")
                )
                comptime appendable = String("...") if optlike.opt_is_appendable else String("")
                comptime fixed_help = optlike.opt_help.replace("\n", "    \n")
                comptime desc_line = t"    {fixed_help}"

                comptime if optlike.opt_is_arg:
                    comptime details_line = String(
                        t"  [{long_name.upper()}]{appendable}{default}\n"
                    )
                    arguments.append(materialize[String(details_line) + String(desc_line)]())
                else:
                    comptime details_line = String(
                        t"  {short_name}--{long_name} {long_name.upper()}{appendable}{default}\n"
                    )
                    options.append(materialize[String(details_line) + String(desc_line)]())
            else:
                comptime long_name = String(
                    t"  --{__to_display_name(field_name)} {field_name.upper()} [Required]"
                )
                options.append(materialize[long_name]())

        comptime if conforms_to(field_type, MojOptDeserializable) and not downcast[
            field_type, MojOptDeserializable
        ]._derive_help():
            continue

        comptime derived_indent = 0 if __is_opt[T]() else indent_level + 1
        var more_help = [
            String(t"{'     ' * derived_indent}{line}")
            for line in get_help[downcast[field_type, _Base], derived_indent + 1]().splitlines()
            if line
        ]
        for line in more_help:
            options.append(line)

    var final_list = [description]
    if len(arguments) > 0:
        if not __is_opt[T]():
            final_list.append("Arguments:")
        final_list.append("\n\n".join(arguments))

    if len(options) > 0:
        if not __is_opt[T]():
            final_list.append("Options:")
        final_list.append("\n\n".join(options))

    var final = "\n".join(final_list)
    return final
