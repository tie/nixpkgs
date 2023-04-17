{ lib, rustPlatform }:
rustPlatform.buildRustPackage {
  name = "eco-server-wrapper";
  src = ./.;

  cargoHash = "sha256-EfpUvckw6+pLxmECepNJgpyi22iT3J25MAmNv6xQIpg=";

  meta = {
    description = "Set up environment for Eco Server";
    license = lib.licenses.unlicense;
    maintainers = [ lib.maintainers.tie ];
    platforms = lib.platforms.linux;
    mainProgram = "wrapper";
  };
}
