{
  lib,
  rustPlatform,
  fetchCrate,
  pkg-config,
  curl,
  openssl,
  stdenv,
  darwin,
}:

rustPlatform.buildRustPackage rec {
  pname = "cargo-public-api";
  version = "0.44.1";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-eKTFLvyP/RhQJJPswfzCjxKGE+fXSPfVrEQBMcK3ytU=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-KT7tAisaIjhiLdt1Nkk6lg5hVqRt9fZWP74VHICWThM=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    curl
    openssl
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [ darwin.apple_sdk.frameworks.Security ];

  # Tests fail
  doCheck = false;

  meta = with lib; {
    description = "List and diff the public API of Rust library crates between releases and commits. Detect breaking API changes and semver violations";
    mainProgram = "cargo-public-api";
    homepage = "https://github.com/Enselic/cargo-public-api";
    changelog = "https://github.com/Enselic/cargo-public-api/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ matthiasbeyer ];
  };
}
