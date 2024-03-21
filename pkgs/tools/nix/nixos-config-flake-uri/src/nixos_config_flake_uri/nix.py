import json
import re
import subprocess
import typing

NIX_COMMAND = ["nix", "--extra-experimental-features", "nix-command flakes"]

NIX_ID_REGEXP = re.compile(r"[a-zA-Z_][a-zA-Z0-9_'-]*")

VERSION_REGEXP = re.compile(r"(?P<version>\d+\.\d+\.\d+)")

# See https://github.com/NixOS/nix/pull/8852
NIX_ABSOLUTE_ATTR_PATH_VERSION = (2, 19, 0)


def run_nix(args: list[str]) -> str:
    """Runs nix command.

    :param args: Arguments for nix invocation.
    :return: Standard output as a string.
    """
    return subprocess.run(
        NIX_COMMAND + args,
        stdout=subprocess.PIPE,
        text=True,
        check=True,
    ).stdout


def nix_version() -> str:
    """Returns the Nix version string."""
    return run_nix(["--version"])


def nix_current_system() -> str:
    """Returns the value of builtins.currentSystem."""
    return run_nix([
        "eval",
        "--raw",
        "--no-pure-eval",
        "--option", "eval-system", "",
        "--expr", "builtins.currentSystem",
    ])


def quote_nix_string(s: str) -> str:
    """Turn a string into a Nix expression representing that string."""
    s = json.dumps(s, ensure_ascii=False)
    return s.replace("$", "\\$")


def quote_nix_identifier(s: str) -> str:
    """Quotes a string if it can’t be used as an identifier directly."""
    if NIX_ID_REGEXP.fullmatch(s) is not None:
        return s
    return quote_nix_string(s)


def quote_nix_attr_path(attr_path: list[str]) -> str:
    """Turns an attribute path into a Nix expression representing that path."""
    return ".".join(quote_nix_identifier(name) for name in attr_path)


def parse_version(s: str) -> typing.Optional[tuple[int, ...]]:
    """Extracts version tuple from a string."""
    m = VERSION_REGEXP.search(s)
    if m is None:
        return None
    version = m.group("version")
    return tuple(int(n) for n in version.split("."))


def supports_abs_attr_path(v: typing.Optional[tuple[int, ...]]) -> bool:
    """Checks whether the given Nix version supports absolute attribute path
    notation."""
    # Assume that the version supports absolute attribute paths if the version
    # is unknown.
    return v is None or v >= NIX_ABSOLUTE_ATTR_PATH_VERSION
