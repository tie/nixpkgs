{
  lib,
  pythonOlder,
  buildPythonPackage,
  fetchPypi,
  ruff,
  cattrs,
  lsprotocol,
  python-lsp-server,
  tomli,
  pytestCheckHook,
}:

buildPythonPackage rec {
  pname = "python-lsp-ruff";
  version = "2.2.2";
  pyproject = true;
  disabled = pythonOlder "3.8";

  src = fetchPypi {
    inherit version;
    pname = "python_lsp_ruff";
    hash = "sha256-P4C9sLSo7iRiRZahz/YLKMw3dxdzcw+b99lG3f+fDKw=";
  };

  postPatch = ''
    # ruff binary is used directly, the ruff python package is not needed
    sed -i '/"ruff>=/d' pyproject.toml
    sed -i 's|sys.executable, "-m", "ruff"|"${ruff}/bin/ruff"|' pylsp_ruff/plugin.py
    sed -i -e '/sys.executable/,+2c"${ruff}/bin/ruff",' -e 's|assert "ruff" in call_args|assert "${ruff}/bin/ruff" in call_args|' tests/test_ruff_lint.py
    # Nix builds everything in /build/ but ruff somehow doesn't run on files in /build/ and outputs empty results.
    sed -i -e "s|workspace.root_path|'/tmp/'|g" tests/*.py
  '';

  dependencies = [
    cattrs
    lsprotocol
    python-lsp-server
  ] ++ lib.optionals (pythonOlder "3.11") [ tomli ];

  nativeCheckInputs = [ pytestCheckHook ];

  meta = {
    homepage = "https://github.com/python-lsp/python-lsp-ruff";
    description = "Ruff linting plugin for pylsp";
    changelog = "https://github.com/python-lsp/python-lsp-ruff/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ linsui ];
  };
}
