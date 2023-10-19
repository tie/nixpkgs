{ fetchpatch }:
let
  name = "darwin-sanbox.patch";
  url = "https://github.com/tie/gyp-next/commit/2c73b7900a8e9887cadf5cf9127101e896e06257.patch";
in
[
  # Fixes builds with Nix sandbox on Darwin for gyp.
  # See https://github.com/NixOS/nixpkgs/issues/261820
  (fetchpatch {
    inherit name url;
    hash = "sha256-IL6vlwvjvC1xZnmQBtHAdoHFyzc0CLoS90odCH5/iDE=";
    stripLen = 1;
    extraPrefix = "tools/gyp/";
  })
  (fetchpatch {
    inherit name url;
    hash = "sha256-xRwlWEb6iA5509oYcSU8y/dib9afGqiHBfQ2OZdAAz0=";
    stripLen = 1;
    extraPrefix = "deps/npm/node_modules/node-gyp/gyp/";
  })
]
