{
  testers,
  fetchGoModules,
  fetchFromGitHub,
  git,
  fossil,
  writableTmpDirAsHomeHook,
  prefetch-go-modules,
  jq,
}:
{
  emptyGoMod = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "emptyGoMod";
    src = ./nodep;
    hash = "sha256-pQpattmS9VmO3ZIQUFn66az8GSmB4IvYhTTCFn6SUmo=";
  };

  go117 = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "go117";
    src = ./go117;
    hash = "sha256-VfQQrYUjcidvBYxPLCCjSX/2b0N8jmCmREUkbm6429A=";
  };

  go116 = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "go116";
    src = ./go116;
    hash = "sha256-VfQQrYUjcidvBYxPLCCjSX/2b0N8jmCmREUkbm6429A=";
  };

  srcWithoutGosum = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "srcWithoutGosum";
    src = ./nosum;
    hash = "sha256-VfQQrYUjcidvBYxPLCCjSX/2b0N8jmCmREUkbm6429A=";
  };

  combinedGo116AndGo117 = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "combinedGo116AndGo117";
    sourceRoot = ".";
    srcs = [
      ./go116
      ./go117
    ];
    modRoots = [
      "go116"
      "go117"
    ];
    hash = "sha256-VfQQrYUjcidvBYxPLCCjSX/2b0N8jmCmREUkbm6429A=";
  };

  goproxyDirectGit = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "goproxyDirectGit";
    src = ./go117;
    hash = "sha256-VfQQrYUjcidvBYxPLCCjSX/2b0N8jmCmREUkbm6429A=";
    nativeBuildInputs = [ git ];
    env.GOPROXY = "direct";
    env.GOVCS = "*:git";
  };

  goproxyDirectFossil = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "goproxyDirectFossil";
    src = ./fossil;
    hash = "sha256-Wp1VIxbbjabFKggxYZct2n1fKaCK87hF+nhzK4GLK70=";
    nativeBuildInputs = [ fossil ];
    env.GOPROXY = "direct";
    env.GOVCS = "*:fossil";
  };

  k8sClientGoproxyOnly = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "k8sClientGoproxyOnly";
    src = ./k8s-client;
    hash = "sha256-EUwnYG9kZcL87dzZiZemAu6pRIDErMxM4rb4i+J5Ihc=";
    env.GOPROXY = "https://proxy.golang.org";
  };

  k8sClientGoproxyDirect = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "k8sClientGoproxyDirect";
    src = ./k8s-client;
    hash = "sha256-EUwnYG9kZcL87dzZiZemAu6pRIDErMxM4rb4i+J5Ihc=";
    nativeBuildInputs = [ git ];
    env.GOPROXY = "direct";
    env.GOVCS = "*:git";
  };

  srcFromGitHub = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "srcFromGitHub";
    src = fetchFromGitHub {
      owner = "rsc";
      repo = "hello";
      tag = "v1.0.0";
      hash = "sha256-M7uvXFUddirgR5iQPWkncR+MFq16B1XQHqIUGQ/AmXw=";
    };
    hash = "sha256-QG/iQBZYB0+p0b/CyFTFyXkriNVPDLkPreuIKweXE70=";
  };

  goworkOn = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "goworkOn";
    src = ./gowork;
    hash = "sha256-SEbhFw9LYeZ9QVhR7cM7yBPOajiX5BT7eVc5nOY1QBg=";
  };

  goworkOff = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "goworkOff";
    src = ./gowork;
    modRoots = [
      "mod1"
      "mod2"
    ];
    hash = "sha256-SEbhFw9LYeZ9QVhR7cM7yBPOajiX5BT7eVc5nOY1QBg=";
    env.GOWORK = "off";
  };

  goworkStandalone = testers.invalidateFetcherByDrvHash fetchGoModules {
    name = "goworkStandalone";
    sourceRoot = ".";
    srcs = [
      ./gowork/mod1
      ./gowork/mod2
    ];
    modRoots = [
      "mod1"
      "mod2"
    ];
    hash = "sha256-SEbhFw9LYeZ9QVhR7cM7yBPOajiX5BT7eVc5nOY1QBg=";
    env.GOWORK = "off";
  };

  prefetchJsonOutput = testers.runCommand {
    name = "prefetchJsonOutput";
    src = ./k8s-client;
    nativeBuildInputs = [
      prefetch-go-modules
      jq
    ];
    expectedHash = "sha256-EUwnYG9kZcL87dzZiZemAu6pRIDErMxM4rb4i+J5Ihc=";
    script = ''
      cp --reflink=auto -r -T "$src" source
      chmod -R +w source
      cd source
      prefetch-go-modules >go-modules.json
      actualHash=$(jq -j .Hash <go-modules.json)
      if [[ $expectedHash != "$actualHash" ]]; then
        echo "expected hash $expectedHash, but got $actualHash" 1>&2
        false
      fi
      touch "$out"
    '';
  };
}
