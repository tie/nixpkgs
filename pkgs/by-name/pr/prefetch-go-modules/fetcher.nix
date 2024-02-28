{
  lib,
  stdenvNoCC,
  cacert,
  go,
  prefetch-go-modules,
}:
let
  fetchGoModules = finalAttrs: prevAttrs: {
    name = prevAttrs.name or "go-modules";

    outputHashMode = "recursive"; # "nar" since Nix 2.21

    # In general, packages shouldn’t override default phases. In our case, we
    # really need only unpack phase to run, and maybe patch phase as well. That
    # is because `go mod download` can update `go.{mod,sum}` files, so we have
    # to copy `src`/`srcs` to a writable directory, and we’d like to reuse
    # default phase implementations for unpacking and patching sources.
    phases = [
      "unpackPhase"
      "patchPhase"
      "fetchPhase"
    ];

    preferLocalBuild = prevAttrs.preferLocalBuild or true;

    strictDeps = true;

    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
      cacert # setupHook
      go
      prefetch-go-modules
    ];

    # See also https://nixos.org/nix/manual/#sec-advanced-attributes
    # Note that we do not add env vars for specific VCS tools.
    impureEnvVars =
      prevAttrs.impureEnvVars or [ ]
      ++ lib.fetchers.proxyImpureEnvVars
      ++ [
        "GOPROXY"
        "GONOPROXY"
        "GOSUMDB"
        "GONOSUMDB"
        "GOPRIVATE"
        "GOINSECURE"
        "GOVCS"
      ];

    # Go uses GOPATH/pkg/sumdb directory to store public key and other metadata
    # if we need to fetch from sumdb (e.g. an entry does not exist in go.sum).
    fetchPhase =
      prevAttrs.fetchPhase or ''
        runHook preFetch
        declare -a modRootsArray
        concatTo modRootsArray modRoots
        GOPATH=$TMPDIR/go \
          prefetch-go-modules -builder \
          -gomodcache="$out" \
          -- "''${modRootsArray[@]}"
        runHook postFetch
      '';
  };
in
lib.makeOverridable (
  lib.fetchers.withNormalizedHash { } (
    args@{ outputHash, outputHashAlgo, ... }:
    stdenvNoCC.mkDerivation (lib.extends fetchGoModules (lib.toFunction args))
  )
)
