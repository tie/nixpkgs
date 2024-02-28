{
  lib,
  stdenv,
  cacert,
  git,
  go,
  goHook,
}:
let
  buildGoModule1 = import ./v1.nix {
    inherit
      lib
      stdenv
      cacert
      git
      go
      ;
  };
  buildGoModule2 = import ./v2.nix {
    inherit
      lib
      stdenv
      go
      goHook
      ;
  };
in
args:
if lib.isFunction args || args ? goModules || !(args ? vendorSha256 || args ? vendorHash) then
  buildGoModule2 args
else
  buildGoModule1 args
