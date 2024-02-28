# shellcheck shell=bash

declare role_post

case "${targetOffset-}" in
-1)
    role_post=_FOR_BUILD
    ;;
0)
    role_post=
    ;;
1)
    role_post=_FOR_TARGET
    ;;
*)
    echo "goToolchainHook: used as improper sort of dependency" >&2
    false
    ;;
esac

# shellcheck disable=SC2086
export \
    GOENV${role_post}=@goenv@ \
    GOROOT${role_post}=@goroot@

unset -v role_post
