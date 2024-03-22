import argparse
import dataclasses
import enum
import typing


class OutputFormat(enum.StrEnum):
    TEXT = enum.auto()
    JSON = enum.auto()
    ENV = enum.auto()


@dataclasses.dataclass(frozen=True)
class TypedArgs:
    flake_uri: str
    nix_version: typing.Optional[str]
    system: typing.Optional[str]
    hostname: typing.Optional[str]
    output_format: OutputFormat
    output_fields: typing.Optional[str]


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="nixos-config-flake-uri",
        description="Discover NixOS configuration flake output attribute path",
    )
    p.add_argument(
        "flake_uri",
        help="flake URI to evaluate",
    )
    p.add_argument(
        "--nix-version",
        help="Nix version to assume for feature checks",
    )
    p.add_argument(
        "--system",
        help="system name to use (defaults to builtins.currentSystem)",
    )
    p.add_argument(
        "--hostname",
        help="hostname to use (defaults to system hostname)",
    )
    p.add_argument(
        "--output-format",
        help="output format to use",
        type=OutputFormat,
        default=OutputFormat.TEXT,
        choices=list(OutputFormat),
    )
    p.add_argument(
        "--output-fields",
        help="comma-separated list of fields for output",
    )
    return p
