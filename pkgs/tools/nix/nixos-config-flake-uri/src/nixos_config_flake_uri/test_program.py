import pytest

from . import program
from . import arguments


@pytest.mark.parametrize("args,output", [
    (
        arguments.TypedArgs(
            flake_uri="",
            nix_version="",
            system="",
            hostname="",
        ),
        "#.configurations.\"\".\"\"",
    ),
    (
        arguments.TypedArgs(
            flake_uri="flake",
            nix_version="",
            system="currentSystem",
            hostname="default",
        ),
        "flake#.configurations.currentSystem.default",
    ),
    (
        arguments.TypedArgs(
            flake_uri="flake#machine",
            nix_version="",
            system="currentSystem",
            hostname="default",
        ),
        "flake#.configurations.currentSystem.machine",
    ),
    (
        arguments.TypedArgs(
            flake_uri="flake#.machine",
            nix_version="",
            system="currentSystem",
            hostname="default",
        ),
        "flake#.machine",
    ),
    (
        arguments.TypedArgs(
            flake_uri="flake",
            nix_version="nix (Nix) 2.19.0",
            system="currentSystem",
            hostname="default",
        ),
        "flake#.configurations.currentSystem.default",
    ),
    (
        arguments.TypedArgs(
            flake_uri="flake",
            nix_version="nix (Nix) 2.18.0",
            system="currentSystem",
            hostname="default",
        ),
        "flake#configurations.currentSystem.default",
    ),
    (
        arguments.TypedArgs(
            flake_uri="flake#.machine",
            nix_version="2.18.0",
            system="currentSystem",
            hostname="default",
        ),
        "flake#machine",
    ),
])
def test_main_output(args: arguments.TypedArgs, output: str) -> None:
    assert program.main(args) == output


@pytest.mark.parametrize("args", [
    arguments.TypedArgs(
        flake_uri="flake#\"",
        nix_version="",
        system="",
        hostname="",
    ),
    arguments.TypedArgs(
        flake_uri="flake",
        nix_version="",
        system="\"",
        hostname="",
    ),
    arguments.TypedArgs(
        flake_uri="flake",
        nix_version="",
        system="",
        hostname="\"",
    ),
])
def test_main_raises_exit(args: arguments.TypedArgs) -> None:
    with pytest.raises(SystemExit):
        program.main(args)
