{ lib, callPackages }:
{
  goHook = lib.recurseIntoAttrs (callPackages ./go-hook/default.nix { });
  fetchGoModules = lib.recurseIntoAttrs (callPackages ./fetch-go-modules/default.nix { });
}
