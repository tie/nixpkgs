from . import arguments
from . import program


def main() -> None:
    args = arguments.TypedArgs(**vars(arguments.parser().parse_args()))
    print(program.main(args))
