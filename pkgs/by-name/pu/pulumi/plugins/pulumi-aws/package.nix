{
  lib,
  fetchFromGitHub,
  buildGoModule,
  buildPackages,
  python3Packages,
  testResourceSchema,
  fetchYarnDeps,
  nodejs,
  yarn,
  fixup-yarn-lock,
  pulumi,
  pulumi-go,
  pulumi-nodejs,
  pulumi-python,
  pulumi-std,
  pulumi-converter-terraform,
  pulumi-aws,
  nix-update-script,
}:
buildGoModule rec {
  pname = "pulumi-aws";
  version = "7.7.0";

  outputs = [
    "out"
    "sdk"
  ];

  src = fetchFromGitHub {
    owner = "pulumi";
    repo = "pulumi-aws";
    tag = "v${version}";
    hash = "sha256-gAondrpQxTWP3v/GcX1g9WuuueFfJVkwiUUr1hcMpes=";
    fetchSubmodules = true;
  };

  sourceRoot = "${src.name}/provider";

  vendorHash = "sha256-jMOZtrPdkt8z/6aFAmrocneOtQbn/sbIwWUk7KdQ+0I=";

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/pulumi/pulumi-aws/provider/v7/pkg/version.Version=${version}"
    "-X=github.com/hashicorp/terraform-provider-aws/version.ProviderVersion=${version}"
  ];

  checkFlags = [
    "-skip=^TestUpstreamLint$"
  ];

  excludedPackages = [
    "cmd/pulumi-tfgen-aws"
  ];

  nativeBuildInputs = [
    pulumi
    pulumi-go
    pulumi-nodejs
    pulumi-python
    pulumi-std
    pulumi-converter-terraform
    nodejs
    yarn
    fixup-yarn-lock
  ];

  yarnOfflineCache = fetchYarnDeps {
    yarnLock = "${src}/upstream-tools/yarn.lock";
    hash = "sha256-hSLBQFrH8pCO9ghpBI2KLHM5U8a3roL4oUEXoeToM8o=";
  };

  # https://github.com/pulumi/pulumi-aws/blob/5bffb1c5af97b8430288cc1bdc61a65bb7153dd2/Makefile#L274-L278
  # https://github.com/pulumi/pulumi-aws/blob/5bffb1c5af97b8430288cc1bdc61a65bb7153dd2/scripts/upstream.sh#L138-L150
  # https://github.com/pulumi/pulumi-aws/blob/5bffb1c5af97b8430288cc1bdc61a65bb7153dd2/upstream-tools/package.json#L11
  #
  # The results of this script are needed for codegen to produce correct output,
  # both when building and running.
  postPatch = ''
    pushd ..
    chmod -R +w upstream
    for patch in patches/*.patch; do
      echo "Applying $patch"
      patch -p1 -d upstream <"$patch"
    done
    popd
  '';
  preConfigure = ''
    pushd ..
    mkdir "$TMPDIR"/yarn
    chmod -R +w upstream-tools
    cp -T upstream-tools/yarn.lock "$TMPDIR"/yarn/original-yarn.lock
    HOME=$TMPDIR/yarn yarn config --offline set yarn-offline-mirror "$yarnOfflineCache"
    HOME=$TMPDIR/yarn fixup-yarn-lock upstream-tools/yarn.lock
    HOME=$TMPDIR/yarn yarn install \
      --cwd upstream-tools \
      --frozen-lockfile \
      --force \
      --production=false \
      --ignore-engines \
      --ignore-platform \
      --ignore-scripts \
      --no-progress \
      --non-interactive \
      --offline
    patchShebangs --build upstream-tools/node_modules
    for script in pre-replace strip-links global-replace; do
      HOME=$TMPDIR/yarn yarn --offline --cwd upstream-tools run "$script"
    done
    mv -T "$TMPDIR"/yarn/original-yarn.lock upstream-tools/yarn.lock
    rm -r upstream-tools/node_modules "$TMPDIR"/yarn
    popd
  '';

  codegen = buildPackages.buildGoModule {
    pname = "pulumi-tfgen-aws";
    inherit
      src
      version
      sourceRoot
      vendorHash
      ldflags
      # For upstream-tools and upstream patches.
      postPatch
      preConfigure
      yarnOfflineCache
      nativeBuildInputs
      ;
    subPackages = [
      "cmd/pulumi-tfgen-aws"
      "cmd/pulumi-resource-aws/generate.go"
    ];
  };

  # https://github.com/pulumi/pulumi-aws/blob/5bffb1c5af97b8430288cc1bdc61a65bb7153dd2/Makefile#L262-L263
  # https://github.com/pulumi/pulumi-aws/blob/5bffb1c5af97b8430288cc1bdc61a65bb7153dd2/scripts/minimal_schema.sh#L7
  postConfigure = ''
    pushd ..
    "$codegen"/bin/pulumi-tfgen-aws schema --out provider/cmd/pulumi-resource-aws
    popd
    pushd cmd/pulumi-resource-aws
    VERSION=$version PULUMI_AWS_MINIMAL_SCHEMA= "$codegen"/bin/generate
    VERSION=$version PULUMI_AWS_MINIMAL_SCHEMA=true "$codegen"/bin/generate
    popd
  '';

  # https://github.com/pulumi/pulumi-aws/blob/24650f317efba2112f2fc0ebf11277ae9c0621d1/provider/resources.go#L5159-L5225
  overlaidFiles = [
    "nodejs/tags.ts"
    "nodejs/utils.ts"
    "nodejs/cloudwatch/cloudwatchMixins.ts"
    "nodejs/cloudwatch/eventRuleMixins.ts"
    "nodejs/cloudwatch/logGroupMixins.ts"
    "nodejs/config/require.ts"
    "nodejs/dynamodb/dynamodbMixins.ts"
    "nodejs/ecr/lifecyclePolicyDocument.ts"
    "nodejs/ecs/container.ts"
    "nodejs/iam/documents.ts"
    "nodejs/iam/principals.ts"
    "nodejs/kinesis/kinesisMixins.ts"
    "nodejs/lambda/lambdaMixins.ts"
    "nodejs/s3/routingRules.ts"
    "nodejs/s3/s3Mixins.ts"
    "nodejs/sns/snsMixins.ts"
    "nodejs/sqs/redrive.ts"
    "nodejs/sqs/sqsMixins.ts"
  ];

  # buildGoModule breaks with structured attributes… :(
  postInstall = ''
    pushd ..
    if [[ -z $__structuredAttrs ]]; then
      overlaidFiles=($overlaidFiles)
    fi
    for f in "''${overlaidFiles[@]}"; do
      install -D -m 444 -t "$sdk/''${f%/*}" "sdk/$f"
    done
    for lang in go nodejs python; do
      PULUMI_CONVERT=1 "$codegen"/bin/pulumi-tfgen-aws "$lang" --out "$sdk/$lang"
    done
    popd
    cp -t "$sdk/python" ../README.md
  '';

  __darwinAllowLocalNetworking = true;

  passthru.tests.schema = testResourceSchema {
    package = pulumi-aws;
  };

  passthru.sdks.python = python3Packages.pulumi-aws;

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version-regex=v(.*)" ];
  };

  meta = {
    description = "Pulumi package for creating and managing Amazon Web Services (AWS) cloud resources";
    mainProgram = "pulumi-resource-aws";
    homepage = "https://github.com/pulumi/pulumi-aws";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      tie
    ];
  };
}
