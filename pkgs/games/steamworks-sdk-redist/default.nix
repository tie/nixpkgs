{ lib
, stdenv
, fetchSteamDepot
}:
stdenv.mkDerivation {
  pname = "steamworks-sdk-redist";
  version = "1.57";

  # Steamworks SDK Redist with steamclient.so.
  # https://steamdb.info/app/1007/depots
  src = fetchSteamDepot {
    appId = "1007";
    depotId = "1006";
    manifestId = "6912453647411644579";
    hash = "sha256-cj853Zk3dU0WICny3soTFppWkf8NJBp6C+Ywb96Yxcs=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp ${lib.optionalString (stdenv.hostPlatform.is64bit) "linux64/"}steamclient.so $out/lib/
    chmod +x $out/lib/steamclient.so

    runHook postInstall
  '';

  meta = {
    description = "Steamworks SDK Redist";
    maintainers = [ lib.maintainers.tie ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
