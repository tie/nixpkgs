import json
import shlex
import socket
import sys

from . import arguments
from . import flakeuri
from . import nix

NIXOS_CONFIGURATIONS_OUTPUT = "nixosConfigurations"


def main() -> None:
    args = arguments.TypedArgs(**vars(arguments.parser().parse_args()))

    flake_ref, flake_uri_fragment = flakeuri.parse_url_fragment(args.flake_uri)

    parsed_attr_path = [
        NIXOS_CONFIGURATIONS_OUTPUT,
    ]
    if flake_uri_fragment is not None:
        try:
            parsed_attr_path = flakeuri.parse_attr_path(
                flake_uri_fragment,
                parsed_attr_path,
            )
        except flakeuri.MissingClosingQuote as ex:
            sys.exit("error: missing closing quote in selection path"
                     f" '{ex.attr_path}'")
    else:
        hostname = (args.hostname if args.hostname is not None
                    else socket.gethostname())
        parsed_attr_path.append(hostname)

    nix_escaped_attr_path = nix.quote_nix_attr_path(parsed_attr_path)

    try:
        url_escaped_attr_path = flakeuri.quote_url_fragment(
            flakeuri.quote_attr_path(parsed_attr_path),
        )
    except flakeuri.MalformedAttributeName:
        # This can happen if hostname contain quotes.
        # Attribute path from URI fragment is safe since otherwise parsing
        # fails with an error due to unbalanced quotes.
        sys.exit(f"error: attribute path {nix_escaped_attr_path} contains"
                 " names with quotes")

    # Use absolute attribute path if possible.
    nix_version = (args.nix_version if args.nix_version is not None
                   else nix.nix_version())
    parsed_nix_version = nix.parse_version(nix_version)
    if nix.supports_abs_attr_path(parsed_nix_version):
        url_escaped_attr_path = "." + url_escaped_attr_path
    flake_uri = f"{flake_ref}#{url_escaped_attr_path}"

    output = {
        "flakeUri": flake_uri,
        "flakeRef": flake_ref,
        "flakeExpr": nix_escaped_attr_path,
        "flakeFragment": url_escaped_attr_path,
    }

    output_fields = (
        args.output_fields.split(",")
        if args.output_fields is not None else None
    )
    if output_fields is None and \
       args.output_format == arguments.OutputFormat.TEXT:
        # Default to only flakeUri for text output format.
        output_fields = ["flakeUri"]
    if output_fields is not None:
        output = {key: output[key] for key in output_fields if key in output}

    match args.output_format:
        case arguments.OutputFormat.TEXT:
            print(dumps_text(output))
        case arguments.OutputFormat.JSON:
            print(json.dumps(output))
        case arguments.OutputFormat.ENV:
            print(dumps_env(output))


def dumps_text(vars: dict[str, str]) -> str:
    return "\n".join(vars.values())


def dumps_env(vars: dict[str, str]) -> str:
    return "".join(f"{k}={shlex.quote(v)}\n" for k, v in vars.items())
