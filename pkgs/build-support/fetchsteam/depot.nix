{ lib, runCommand, pkgsBuildBuild, cacert }:
lib.makeOverridable (
  { name ? "steamapp-${appId}-${depotId}-${manifestId}"
  , hash ? lib.fakeHash
  , appId
  , depotId
  , manifestId
  , passthru ? { }
  , meta ? { }
  }@args:
  let
    # Set meta.position similar to fetchFromGitHub.
    position =
      if args.meta.description or null != null
      then builtins.unsafeGetAttrPos "description" args.meta
      else builtins.unsafeGetAttrPos "appId" args;
    newMeta = {
      position = "${position.file}:${toString position.line}";
    } // meta;
  in
  runCommand name
  {
    nativeBuildInputs = [ pkgsBuildBuild.depotdownloader ];

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = hash;

    inherit passthru;
    meta = newMeta;
  } ''
    export HOME=$PWD
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    DepotDownloader \
      -app ${lib.escapeShellArg (toString appId)} \
      -depot ${lib.escapeShellArg (toString depotId)} \
      -manifest ${lib.escapeShellArg (toString manifestId)} \
      -dir $out
    rm -r $out/.DepotDownloader
  ''
)
