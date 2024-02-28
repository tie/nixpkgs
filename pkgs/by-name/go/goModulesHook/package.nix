{
  lib,
  makeSetupHook,
  goToolchainHook,
  testers,
  tests,
}:
makeSetupHook {
  name = "go-modules-hook";
  propagatedBuildInputs = [ goToolchainHook ];
  passthru.tests = lib.filterAttrs (_: lib.isDerivation) tests.go.goModulesHook // {
    shellcheck = testers.shellcheck {
      src = ./setup-hook.sh;
    };
  };
  meta = {
    description = "Setup hook for Go modules";
    maintainers = lib.teams.golang.members ++ [
      lib.maintainers.tie
    ];
  };
} ./setup-hook.sh
