import pytest

from . import nix


@pytest.mark.parametrize("version,expect", [
    ("nix (Nix) 2.18.1", (2, 18, 1)),
    ("42.0.3pre-rc1.2.3", (42, 0, 3)),
    ("foo bar 69", None),
])
def test_parse_version(
    version: str,
    expect: tuple[int, ...],
) -> None:
    assert nix.parse_version(version) == expect
