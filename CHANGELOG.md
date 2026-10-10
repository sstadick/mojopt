# CHANGELOG

## v0.5.0
- Update compiler, package recipe, and development environment to stable Mojo 1.1.0.
- Migrate array and tuple deserialization to the new `MaybeUninit` lifecycle API without legacy closures.
- Preserve cleanup of partially parsed containers and support non-trivially movable elements.
- Update tuple parameters and trivial-deinitialization predicates to current APIs.
- Add Linux AArch64 support and validate all supported platforms in CI.

## v0.4.0
- [chore](https://github.com/sstadick/mojopt/pull/7): Update to the stable Mojo v1.0.0 release
- Add MIT and Unlicense licensing files

## v0.3.0
- [chore](https://github.com/sstadick/mojopt/pull/6): Updates for Mojo v1.0.0b

## v0.2.0
- [feat](https://github.com/sstadick/mojopt/pull/5): GNU compliant help output

## v0.1.1
- [fix](https://github.com/sstadick/mojopt/pull/4): don't print a default value if Opt is not defaultable and doesn't have a default_value

## v0.1.0
- Initial release
