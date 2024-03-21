import dataclasses
import typing
import urllib.parse

# We follow Nix installable format for flake URIs. That means that we also
# support absolute attribute path notation introduced in Nix 2.19.
# References:
# https://github.com/NixOS/nix/blob/34807c8906a61219ec2e9132c9cf0bd4d29e1d12/src/libexpr/attr-path.cc#L8-L31
# https://github.com/NixOS/nix/blob/34807c8906a61219ec2e9132c9cf0bd4d29e1d12/src/libexpr/flake/flakeref.cc#L81-L94
# https://github.com/NixOS/nix/blob/34807c8906a61219ec2e9132c9cf0bd4d29e1d12/src/libutil/url-parts.hh#L22

# NB these characters are never quoted: a-zA-Z0-9-._~
FRAGMENT_SAFE_CHARACTERS = "".join([
    # fragmentRegex
    "/",
    "?",
    " ",
    "^",
    # pcharRegex
    ":",
    "@",
    # subdelimsRegex
    "!",
    "$",
    "&",
    "'",
    "\"",
    "(",
    ")",
    "*",
    "+",
    ",",
    ";",
    "=",
])


@dataclasses.dataclass(frozen=True)
class MissingClosingQuote(Exception):
    attr_path: str


@dataclasses.dataclass(frozen=True)
class MalformedAttributeName(Exception):
    pass


def quote_url_fragment(s: str) -> str:
    """Quotes URI fragment with an extended safe characters set.

    :param s: URI fragment to encode.
    :return: URI fragment with percent-encoded unsafe characters.
    """
    return urllib.parse.quote(s, safe=FRAGMENT_SAFE_CHARACTERS)


def parse_url_fragment(flake_uri: str) -> tuple[str, typing.Optional[str]]:
    """Parses fragment from flake URI.

    :param flake_uri: URI to parse.
    :return: A tuple of flake reference (URI without fragment) and an optional
        fragment (if it exists).
    """
    flake_ref, sep, attr_path = flake_uri.partition("#")
    if sep == "":
        return (flake_ref, None)
    attr_path = urllib.parse.unquote(attr_path)
    return (flake_ref, attr_path)


def quote_attr_name(s: str) -> str:
    """Quotes attribute name for use in URI fragment attribute path.

    :param s: Attribute name to quote.
    :return: Quoted attribute name.
    :raises MalformedAttributeName: If attribute name contains quotes.
    """

    # Nix does not support escaping quotes in flake URI fragments.
    if "\"" in s:
        raise MalformedAttributeName()

    # While not strictly necessary, we also quote empty string.
    if "." in s or s == "":
        s = f"\"{s}\""

    return s


def quote_attr_path(attr_path: list[str]) -> str:
    """Quotes attribute path for use in URI fragment.

    :param attr_path: Attribute path to quote.
    :return: URI fragment representing the given attribute path.
    :raises MalformedAttributeName: If attribute path contains names with
        quotes.
    """
    return ".".join(quote_attr_name(v) for v in attr_path)


def parse_attr_path(selector: str, prefix: list[str] = []) -> list[str]:
    """Parses attribute path from URI fragment attribute selector.

    :param selector: Attribute selector from flake URI.
    :param prefix: Attribute path prefix for relative selectors.
    :raises MissingClosingQuote: If the selector contains unbalanced quotes.
    """

    s = selector

    absolute = s.startswith(".")
    if absolute:
        s = s[1:]

    attr_path = list(prefix) if not absolute else []
    current = ""
    while len(s) > 0:
        try:
            i, c = next((i, c) for i, c in enumerate(s) if c in [".", "\""])
        except StopIteration:
            attr_path.append(current + s)
            current = ""
            break
        current += s[:i]
        s = s[i+1:]
        match c:
            case "\"":
                index = s.find("\"")
                if index == -1:
                    raise MissingClosingQuote(selector)
                current += s[:index]
                s = s[index+1:]
            # Nix ignores trailing dot, e.g. "nixpkgs#hello." is identical to
            # "nixpkgs#hello". We do the same, that is, loop stops if we are
            # at the end of the string.
            case ".":
                attr_path.append(current)
                current = ""
    if current != "":
        attr_path.append(current)
    return attr_path
