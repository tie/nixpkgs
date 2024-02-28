# shellcheck shell=bash

goBuildHook() {
    runHook preGoBuild
    _runGoCommandInModRoots build
    runHook postGoBuild
}

goTestHook() {
    runHook preGoTest
    _runGoCommandInModRoots test
    runHook postGoTest
}

goInstallHook() {
    runHook preGoInstall
    # shellcheck disable=SC2154
    installGoExecutables "${!outputBin}/bin"
    runHook postGoInstall
}

setupGoPhase() {
    runHook preSetupGo

    export GOMAXPROCS=$NIX_BUILD_CORES

    export GO111MODULE=on
    export GOTOOLCHAIN=local
    export GOPROXY=off
    export GOSUMDB=off

    export GOPATH=$TMPDIR/gopath
    export GOBIN=$TMPDIR/gobin
    export GOCACHE=$TMPDIR/gocache
    export GOMODCACHE=$TMPDIR/gomodcache

    # Automatically set up fetchGoModules output if available.
    if [[ -n ${goModules-} ]]; then
        # Optionally, allow behavior similar to proxyVendor from the old
        # buildGoModule. In particular, this keeps GOMODCACHE set to a writable
        # directory, but requires copying modules there, so is less efficient.
        if [[ -n ${proxyGoModules-} ]]; then
            GOPROXY=file://$goModules/cache/download
        else
            GOMODCACHE=$goModules
        fi
    fi

    local goversion
    goversion=$(_gorootGo env GOVERSION)
    echoCmd "go version" "$goversion"
    echoCmd "go env GOROOT" "$GOROOT"

    runHook postSetupGo
}

_gorootGo() {
    "$GOROOT/bin/go" "$@"
}

_runGoCommandInModRoots() {
    local cmd=$1

    local -a dirs
    concatTo dirs modRoots

    # If no modRoots are defined, default to an empty string (i.e. current
    # working directory).
    dirs=("${dirs[@]-}")

    local -a packages
    concatTo packages goPackages "${cmd}GoPackages"

    local modRoot
    for modRoot in "${dirs[@]}"; do
        _runGoCommand "$cmd" "$modRoot" "${packages[@]}"
    done
}

_runGoCommand() {
    local cmd=$1
    local modRoot=$2
    local packages=("${@:3}")

    # Default to all packages in the main module if no packages were given via
    # function arguments.
    packages=("${packages[@]-./...}")

    # This adds "./" prefix to all elements that have "-" prefix. Ensures that
    # package patterns are not flags.
    packages=("${packages[@]/#-/./-}")

    local tags ldflags
    tags=$(concatStringsSep "," goTags)
    ldflags=$(concatStringsSep " " goLdflags)

    # Omit the symbol table and debug information by default, but respect
    # dontStrip derivation attribute. Note that -s implies -w since Go 1.22.
    if [[ -z ${dontStrip-} ]]; then
        ldflags="-s${ldflags:+ }$ldflags"
    fi

    # Unlike old buildGoModule, we always set -trimpath. The motivation for the
    # old behavior was to allow referencing test assets, but Go runs tests in
    # package’s directory, so e.g. tests can use os.Open with relative path to
    # read from standard testdata directory, and we also export GOROOT. Using
    # same flags for build and tests allows compilation cache reuse.
    #
    # Rare packages that actually need trimpath disabled for tests can override
    # this with `goTestFlags = [ "-trimpath=false" ];` in Nix. If Go is required
    # at runtime, use `makeBinaryWrapper` to set `GOROOT` or add Go to `PATH`.
    #
    # In addition to that, we do not set buildid to an empty string since it
    # should not affect reproducibility. There were some bugs in the past (e.g.
    # https://go.dev/issue/33772), but these days BuildID should not be affected
    # by build directory with -trimpath set.
    local flags=(
        ${modRoot:+"-C=$modRoot"}
        -trimpath
        ${proxyGoModules:+"-modcacherw"}
        ${tags:+"-tags=$tags"}
        ${ldflags:+"-ldflags=$ldflags"}
    )
    if [[ ${NIX_DEBUG:-0} -ge 1 ]]; then
        flags+=(-x)
    fi

    # Currently pie is only enabled by default in pkgsMusl. This will respect
    # the `hardening{Disable,Enable}` flags if set.
    if [[ $NIX_HARDENING_ENABLE =~ pie ]]; then
        flags+=(-buildmode=pie)
    fi

    case "$cmd" in
    build)
        local p=1
        if [[ -n ${enableParallelBuilding-} ]]; then
            p=$NIX_BUILD_CORES
        fi
        flags+=("-p=$p")
        flags+=("-o=$GOBIN/")
        concatTo flags goFlags goBuildFlags
        ;;
    test)
        local p=1
        if [[ -n ${enableParallelChecking-} ]]; then
            p=$NIX_BUILD_CORES
        fi
        flags+=(-p="$p" -parallel="$p" -cpu="$p")
        flags+=(-vet=off)
        concatTo flags goFlags goTestFlags
        ;;
    esac
    echoCmd "go $cmd flags" "${flags[@]}" "${packages[@]}"
    _gorootGo "$cmd" "${flags[@]}" "${packages[@]}"
}

# Usage: buildGoPackages <modroot> [<packages>...]
buildGoPackages() {
    _runGoCommand build "$@"
}

# Usage: testGoPackages <modroot> [<packages>...]
testGoPackages() {
    _runGoCommand test "$@"
}

# Usage: installGoExecutables <dest>
installGoExecutables() {
    local dest=$1

    local -a executables
    concatTo executables goExecutables

    local exe
    if [[ ${#executables[@]} -gt 0 ]]; then
        local exeSuffix
        exeSuffix=$(_gorootGo env GOEXE)
        for exe in "${executables[@]}"; do
            install -D -m555 -t "$dest" "$GOBIN/$exe$exeSuffix"
        done
    else
        for exe in "$GOBIN"/*; do
            install -D -m555 -t "$dest" "$exe"
        done
    fi
}

# We expect to be run from depsBuildHost (a.k.a. nativeBuildInputs).
#
# Note that propagated goToolchainHook sets up GOENV and GOROOT that we use.
# For other offsets, we either cannot execute go or these variables have suffix
# (e.g. GOENV_FOR_BUILD).
#
# See also
# https://nixos.org/manual/nixpkgs/stable/#ssec-stdenv-dependencies-propagated
if [[ ${hostOffset-} == -1 && ${targetOffset-} == 0 ]]; then
    appendToVar prePhases setupGoPhase
    if [[ -z ${dontGoBuild-} ]]; then
        appendToVar preBuildHooks goBuildHook
    fi
    if [[ -z ${dontGoTest-} ]]; then
        prependToVar preCheckHooks goTestHook
    fi
    if [[ -z ${dontGoInstall-} ]]; then
        appendToVar preInstallHooks goInstallHook
    fi
fi
