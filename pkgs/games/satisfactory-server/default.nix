{ lib
, stdenv
, gcc-unwrapped
, fetchSteamDepot
, callPackage
, makeBinaryWrapper
, autoPatchelfHook
, steamworks-sdk-redist
, runCommandLocal
}:
let
  wrapper = callPackage ./wrapper { };

  projectRoot = "${placeholder "out"}/share/satisfactory-server";

  # Before Update 8 (UE4).
  serverFileUE4 = "${projectRoot}/Engine/Binaries/Linux/UE4Server-Linux-Shipping";
  # Since Update 8 (UE5).
  serverFileUE5 = "${projectRoot}/Engine/Binaries/Linux/UnrealServer-Linux-Shipping";

  appId = "1690800";
in
stdenv.mkDerivation {
  pname = "satisfactory-server";
  # See Engine/Binaries/Linux/UnrealServer-Linux-Shipping.version for UE5
  # or Engine/Binaries/Linux/UE4Server-Linux-Shipping.version for UE4.
  version = "0.7.1.1-4.26.2+211839";

  # See https://steamdb.info/app/1690800 for a list of manifest IDs.
  src = fetchSteamDepot {
    inherit appId;
    depotId = "1690802";
    manifestId = "6629812905070431503";
    hash = "sha256-7a4k0SYSBaIz6GOrGygNiI+R3z2hn9/JPevOa9TVBew=";
  };

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ autoPatchelfHook makeBinaryWrapper ];

  buildInputs = [
    # NB stdenv.cc.cc.lib doesn’t work with pkgsCross because for some reason
    # lib is under x86_64-unknown-linux-gnu/lib.
    (lib.getLib gcc-unwrapped)
  ];
  appendRunpaths = [ "${steamworks-sdk-redist}/lib" ];

  installPhase = ''
    runHook preInstall

    rm FactoryServer.sh

    mkdir -p ${projectRoot}
    cp -r . ${projectRoot}

    serverFile=${serverFileUE5}
    if [ -e ${serverFileUE4} ]; then
      serverFile=${serverFileUE4}
    fi
    chmod +x $serverFile

    # Mountpoints for wrapper.
    mkdir ${projectRoot}/{Engine,FactoryGame}/Saved

    makeWrapper ${lib.getExe wrapper} $out/bin/satisfactory-server \
      --set-default SteamAppId ${appId} \
      --inherit-argv0 \
      --add-flags -p \
      --add-flags ${projectRoot} \
      --add-flags -e \
      --add-flags $serverFile \
      --add-flags FactoryGame

    runHook postInstall
  '';

  meta = {
    description = "Satisfactory Dedicated Server";
    homepage = "https://satisfactorygame.com";
    maintainers = [ lib.maintainers.tie ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    #license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
