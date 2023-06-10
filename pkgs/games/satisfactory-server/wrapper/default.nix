{ lib, rustPlatform }:
rustPlatform.buildRustPackage {
  name = "satisfactory-server-wrapper";
  src = ./.;

  cargoHash = "sha256-f1hkFNJsMWYc8r133E/A6qTxyElxppNWm1IsJNfOdow=";

  meta = {
    description = "Set up environment for Satisfactory Server";
    license = lib.licenses.unlicense;
    maintainers = [ lib.maintainers.tie ];
    platforms = lib.platforms.linux;
    mainProgram = "wrapper";
  };
}
