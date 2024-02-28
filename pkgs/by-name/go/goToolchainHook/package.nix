{
  lib,
  stdenvNoCC,
  go,
  testers,
}:
let
  # See `go help environment` for documentation.
  # https://pkg.go.dev/cmd/go#hdr-Environment_variables
  toGOOS =
    platform:
    if platform.isAndroid then
      "android"
    else if platform.isWasi then
      "wasip1"
    else if platform.isWasm then
      "js"
    else
      platform.parsed.kernel.name;
  toGOARCH =
    platform:
    if platform.isx86_32 then
      "386"
    else if platform.isx86_64 then
      "amd64"
    else if platform.isAarch32 then
      "arm"
    else if platform.isAarch64 then
      "arm64"
    else if platform.isLoongArch64 then
      "loong64"
    else if platform.isMips then
      "mips" + lib.optionalString platform.is64bit "64" + lib.optionalString platform.isLittleEndian "le"
    else if platform.isPower64 then
      "ppc64" + lib.optionalString platform.isLittleEndian "le"
    # Go does not support 32-bit WASM. See https://go.dev/issue/63131
    else if platform.isWasm && platform.is64bit then
      "wasm"
    else
      platform.parsed.cpu.name;
  toGoEnv =
    platform:
    let
      gccCpu = platform.gcc.cpu or "";
      gccArch = platform.gcc.arch or "";
      softfloat = platform.gcc.float or (platform.parsed.abi.float or "hard") == "soft";
    in
    {
      GOOS = toGOOS platform;
      GOARCH = toGOARCH platform;

      # Note that we do not set up toolchain for Cgo, i.e. we do not set
      # {CC,CXX,AR,FC,PKG_CONFIG}. In Nixpkgs, these are already set by pkgconf
      # and cc-wrapper (a.k.a stdenv.cc) setup hooks.
      CGO_ENABLED = if platform.isWasi then "0" else "1";
    }
    // lib.optionalAttrs platform.isAarch32 {
      GOARM =
        let
          cpuVersion = platform.parsed.cpu.version or "";
          version =
            if
              builtins.elem cpuVersion [
                "5"
                "6"
                "7"
              ]
            then
              cpuVersion
            else
              "7";
          float = if softfloat then "softfloat" else "hardfloat";
        in
        version + "," + float;
    }
    // lib.optionalAttrs platform.isAarch64 {
      GOARM64 =
        # Convert gccArch to GOARM64 value.
        # E.g. armv8.3-a+crypto+sha2+aes+crc+fp16+lse+simd+ras+rdm+rcpc
        # => v8.3,crypto,lse
        let
          matches = builtins.match ''arm(v8|v8\.[0-9]|v9\.[0-5])[^+]*\+?(.*)'' gccArch;

          matchedVersion = builtins.elemAt matches 0;
          matchedExtensions = builtins.elemAt matches 1;

          versionSuffix = lib.optionalString (!lib.hasInfix "." matchedVersion) ".0";

          version = matchedVersion + versionSuffix;
          extensions = lib.splitString "+" matchedExtensions;
        in
        if (matches != null) then
          lib.concatStringsSep "," (
            [ version ]
            ++ lib.intersectLists extensions [
              "lse"
              "crypto"
            ]
          )
        else
          "v8.0";
    }
    // lib.optionalAttrs platform.isx86_32 {
      GO386 = if softfloat then "softfloat" else "sse2";
    }
    // lib.optionalAttrs platform.isx86_64 {
      GOAMD64 =
        {
          x86-64-v2 = "v2";
          x86-64-v3 = "v3";
          x86-64-v4 = "v4";
        }
        .${gccArch} or "v1";
    }
    // lib.optionalAttrs platform.isMips32 {
      GOMIPS = if softfloat then "softfloat" else "hardfloat";
    }
    // lib.optionalAttrs platform.isMips64 {
      GOMIPS64 = if softfloat then "softfloat" else "hardfloat";
    }
    // lib.optionalAttrs platform.isPower64 {
      GOPPC64 =
        if
          builtins.elem gccCpu [
            "power8"
            "power9"
            "power10"
          ]
        then
          gccCpu
        else
          "power8";
    }
    // lib.optionalAttrs platform.isRiscV64 {
      GORISCV64 =
        if
          builtins.elem gccArch [
            "rva20u64"
            "rva22u64"
          ]
        then
          gccArch
        else
          "rva20u64";
    }
    // (platform.go or { });

  goEnv = toGoEnv stdenvNoCC.targetPlatform;
in
stdenvNoCC.mkDerivation {
  name = "go-toolchain-hook";

  outputs = [
    "out"
    "dev"
  ];

  dontUnpack = true;

  strictDeps = true;
  nativeBuildInputs = [ go ];
  propagatedBuildInputs = [ go ];

  goEnvArgs = lib.mapAttrsToList (n: v: n + "=" + v) goEnv;

  buildPhase = ''
    runHook preBuild
    declare -a goEnvArgsArray
    concatTo goEnvArgsArray goEnvArgs
    GOENV=$goenv go env -w -- "''${goEnvArgsArray[@]}"
    runHook postBuild
  '';

  env = {
    goenv = "${placeholder "out"}/share/go/go.env";
    goroot = "${go}/share/go";
  };

  setupHook = ./setup-hook.sh;

  passthru = {
    inherit go goEnv;
    tests.shellcheck = testers.shellcheck {
      src = ./setup-hook.sh;
    };
  };

  meta = {
    description = "Setup hook for Go toolchain";
    maintainers = lib.teams.golang.members ++ [
      lib.maintainers.tie
    ];
  };
}
