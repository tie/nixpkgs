{ lib
, python3
, python3Packages
, runCommand
}:
let
  src = ./src;
  lint = name: withPackages: script:
    runCommand "${name}-check"
      {
        inherit src;
        nativeBuildInputs = [
          (python3.withPackages withPackages)
        ];
      }
      ''
        ${script}
        touch "$out"
      '';
in
python3Packages.buildPythonApplication {
  pname = "nixos-config-flake-uri";
  version = "0.0";
  format = "pyproject";

  inherit src;

  nativeBuildInputs = with python3Packages; [
    setuptools
    pytestCheckHook
  ];

  passthru.tests = {
    mypy = lint "mypy-check"
      (ps: with ps; [ pytest mypy ])
      ''mypy --strict "$src"'';
    flake8 = lint "flake8-check"
      (ps: with ps; [ flake8 ])
      ''flake8 --show-source "$src"'';
  };

  meta = {
    description = "Discover NixOS configuration flake output attribute path";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
