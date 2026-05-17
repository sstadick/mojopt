from std.testing import TestSuite, assert_true


def test_discovered_assertion() raises:
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
