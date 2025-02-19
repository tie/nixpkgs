{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule rec {
  pname = "pulumi-yaml";
  version = "1.23.1";

  src = fetchFromGitHub {
    owner = "pulumi";
    repo = "pulumi-yaml";
    tag = "v${version}";
    hash = "sha256-chP4OpTQb8r5HtSX9YjEa3MDsqo5sAiLhWBOSuIoAyk=";
  };

  vendorHash = "sha256-Rieg2Ztmv30Cf+T/Pobt1vLHqOQIy413BvCCLsUBI1k=";

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/pulumi/pulumi-yaml/pkg/version.Version=${version}"
  ];

  excludedPackages = [
    "pulumi/"
    "scripts/gocov"
    "pkg/tests/testprovider"
  ];

  checkFlags = [
    # Skip integration tests.
    "-short"
    "-skip=^${
      lib.concatStringsSep "$|^" [
        # Requires pulumi submodule with pulumi-language-test.
        "TestLanguage"
        # Requires output from scripts/get_schemas.json.
        "TestGenerateExamples"
        "TestGenerateProgram"
        "TestImportTemplate"
        # Requires pulumi executable.
        "TestAbout"
        "TestAuthoredComponent"
        "TestEnvVarsKeepConflictingValues"
        "TestEnvVarsPassedToExecCommand"
        "TestLocalPlugin"
        "TestParameterized"
        "TestPluginDownloadURLUsed"
        "TestProjectConfigWithSecret"
        "TestProjectConfigWithSecretDecrypted"
        "TestPropertyAccessOnObjects"
        "TestRemoteComponent"
        "TestRemoteComponentTagged"
        "TestResourceOrderingWithDefaultProvider"
        "TestResourcePropertiesConfig"
        "TestResourceSecret"
      ]
    }$"
  ];

  __darwinAllowLocalNetworking = true;

  passthru.updateScript = nix-update-script { };

  meta = {
    homepage = "https://www.pulumi.com/docs/iac/languages-sdks/yaml/";
    description = "Language host for Pulumi programs written in YAML";
    license = lib.licenses.asl20;
    mainProgram = "pulumi-language-yaml";
    maintainers = with lib.maintainers; [
      tie
    ];
  };
}
