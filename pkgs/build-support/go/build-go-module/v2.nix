{
  lib,
  stdenv,
  goHook,
  go,
}:
let
  canExecute = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  buildGoModule2 = _: prevAttrs: {
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
      goHook
      go
    ];

    strictDeps = true;
    enableParallelBuilding = prevAttrs.enableParallelBuilding or true;
    enableParallelChecking = prevAttrs.enableParallelChecking or true;

    doGoTest = prevAttrs.doGoTest or canExecute;

    meta = {
      platforms = go.meta.platforms or lib.platforms.all;
    } // prevAttrs.meta or { };
  };
  buildGoModule1 = finalAttrs: prevAttrs: {
    goTags = finalAttrs.tags or [ ] ++ prevAttrs.goTags or [ ];
    goLdflags = finalAttrs.ldflags or [ ] ++ prevAttrs.goLdflags or [ ];
  };
  buildGoModule = lib.composeExtensions buildGoModule1 buildGoModule2;
in
args: stdenv.mkDerivation (lib.extends buildGoModule (lib.toFunction args))
