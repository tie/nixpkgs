{
  stdenv,
  fetchFromGitHub,
  fetchGoModules,
  goHook,
}:
let
  golang-org-x-example = fetchFromGitHub {
    owner = "golang";
    repo = "example";
    rev = "40afcb705d05179afce97d51b6677e46b5b48bf5";
    hash = "sha256-y5/MWrrMQrHxPXzzK7ElggEr7Mr1L+KGsMAfxhWz2CU=";
  };
in
{
  multipleModules = stdenv.mkDerivation (finalAttrs: {
    name = "go-hook-test-multipleModules";
    src = golang-org-x-example;
    goModules = fetchGoModules {
      inherit (finalAttrs) src modRoots;
      hash = "sha256-gIe5rnfBBAchB1nq3kl/feettgLDXmw0mO1c0M+i6II=";
    };
    nativeBuildInputs = [ goHook ];
    doCheck = false;
    doInstallCheck = true;
    modRoots = [
      "ragserver/ragserver"
      "ragserver/ragserver-genkit"
      "ragserver/ragserver-langchaingo"
    ];
    installCheckPhase = ''
      runHook preInstallCheckPhase
      for exe in ragserver ragserver-genkit ragserver-langchaingo; do
        test -x "$out/bin/$exe"
      done
      runHook postInstallCheckPhase
    '';
  });

  proxyGoModules = stdenv.mkDerivation (finalAttrs: {
    name = "go-hook-test-proxyGoModules";
    src = golang-org-x-example;
    goModules = fetchGoModules {
      inherit (finalAttrs) src modRoots;
      hash = "sha256-D1yHzhHueQsZWthoPI2Pxof5+dLCz05zkT2XybC9Ehk=";
    };
    nativeBuildInputs = [ goHook ];
    proxyGoModules = true;
    modRoots = [
      "ragserver/ragserver"
    ];
  });

  packageFromLocalGoMod = stdenv.mkDerivation (finalAttrs: {
    name = "go-hook-test-localGoMod";
    src = ./local-go-mod;
    goModules = fetchGoModules {
      inherit (finalAttrs) src;
      hash = "sha256-vXQotvQIMGhy1JulPGE1H+iCf6Ef9V/qUvMWc/Mfwfo=";
    };
    nativeBuildInputs = [ goHook ];
    doCheck = false;
    buildGoPackages = [
      "honnef.co/go/tools/cmd/staticcheck"
    ];
  });
}
