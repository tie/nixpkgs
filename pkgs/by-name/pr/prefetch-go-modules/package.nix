{
  lib,
  stdenv,
  go,
  goModulesHook,
  tests,
}:
stdenv.mkDerivation {
  name = "prefetch-go-modules";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      ./cmd
    ];
  };

  strictDeps = true;
  nativeBuildInputs = [ goModulesHook ];

  goLdflags = [ "-X=main.goexe=${lib.getExe go}" ];

  doCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  passthru.tests = lib.filterAttrs (_: lib.isDerivation) tests.go.fetchGoModules;

  meta = {
    inherit (go.meta) platforms;
    description = "Prefetch Go module dependencies (for use with fetchGoModules)";
    maintainers = lib.teams.golang.members ++ [
      lib.maintainers.tie
    ];
  };
}
