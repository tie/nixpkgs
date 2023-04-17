{ lib
, stdenv
, patchelf
, zlib
, icu
, openssl
, libgdiplus
, libkrb5
, fetchSteamDepot
, callPackage
, makeBinaryWrapper
}:
let
  wrapper = callPackage ./wrapper { };
in
stdenv.mkDerivation (self:
let
  # See https://steamdb.info/app/739590 for a list of manifest IDs.
  # See https://hub.docker.com/r/strangeloopgames/eco-game-server/tags
  # for a list of versions.
  appId = "739590";
  depot = {
    "x86_64-linux" = {
      "0.9.7.13-beta-release-506" = {
        depotId = "739595";
        manifestId = "8219186255245898674";
        hash = "sha256-rlKq3xE3hVuzO2Dll8L/qyRid0hzbsyTwu24eZRNUig=";
      };
      "0.9.7.12-beta-release-482" = {
        depotId = "739595";
        manifestId = "4869712459083930124";
        hash = "sha256-9gdNx1DZYz96XbbBfxF8NbN9Fq8BrLtzc1aM80Gs9Ok=";
      };
    };
  }.${stdenv.hostPlatform.system}.${self.version};
in
{
  pname = "eco-server";
  version = "0.9.7.13-beta-release-506";

  src = fetchSteamDepot {
    inherit appId;
    inherit (depot)
      depotId
      manifestId
      hash;
  };

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ patchelf makeBinaryWrapper ];

  installPhase = let share = "share/eco-server"; in ''
    runHook preInstall

    mkdir -p "$out/${share}"
    cp -a . "$out/${share}"

    pushd "$out/${share}"
    chmod +x EcoServer
    rmdir Storage
    rm install.sh
    rm EcoServerInTerminal.sh
    mkdir WebClient/WebBin/Layers
    popd

    makeWrapper ${lib.getExe wrapper} "$out/bin/eco-server" \
      --inherit-argv0 \
      --add-flags -s \
      --add-flags ${placeholder "out"}/${share} \
      --add-flags --

    runHook postInstall
  '';

  fixupPhase = ''
    runHook preFixup

    patchelf \
      --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath ${lib.escapeShellArg (lib.makeLibraryPath [
        stdenv.cc.cc # libstdc++.so.6, libgcc_s.so.1
        zlib
        # .NET dependencies, not listed explicitly in ELF headers.
        icu
        openssl
        libgdiplus
        libkrb5
      ])} \
      "$out/share/eco-server/EcoServer"

    runHook postFixup
  '';

  passthru = {
    inherit wrapper;
  };

  # Note that Strage Loop Games provides paid Eco source code access, see
  # https://play.eco/buy
  meta = {
    description = "Eco Server (not oficially supported)";
    homepage = "https://play.eco";
    maintainers = [ lib.maintainers.tie ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    #license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
})
