{ lib
, fetchFromGitHub
, buildNpmPackage
}:
buildNpmPackage rec {
  pname = "flood";
  version = "4.7.0";
  src = fetchFromGitHub {
    owner = "jesec";
    repo = "flood";
    rev = "v${version}";
    hash = "sha256-BR+ZGkBBfd0dSQqAvujsbgsEPFYw/ThrylxUbOksYxM=";
  };

  NODE_OPTIONS = "--openssl-legacy-provider";

  npmDepsHash = "sha256-tuEfyePwlOy2/mOPdXbqJskO6IowvAP4DWg8xSZwbJw=";

  meta = {
    description = "A modern Web UI for various torrent clients with multi-user and multi-client support";
    homepage = "https://flood.js.org";
    license = [ lib.licenses.gpl3 ];
    maintainers = [ lib.maintainers.tie ];
  };
}
