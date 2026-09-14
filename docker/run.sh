#!/usr/bin/env bash
# Platform-aware launcher for the libasm test container.
#
# Written for bash 3.2 — the version macOS still ships. No associative arrays,
# no ${var,,}, no mapfile. It has to run on the Mac as well as on Linux.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE="libasm-env:amd64"

HOST_OS="$(uname -s)"
HOST_ARCH="$(uname -m)"

# Normalise: macOS says arm64, Linux says aarch64, both mean the same thing.
case "$HOST_ARCH" in
    arm64|aarch64) NATIVE_ARCH="arm64" ;;
    x86_64|amd64)  NATIVE_ARCH="amd64" ;;
    *) echo "unsupported host architecture: $HOST_ARCH" >&2; exit 1 ;;
esac

# libasm is x86_64 assembly. There is no --platform choice to make: an arm64
# container could not assemble the project at all. The flag is accepted only so
# that typing it gives you an explanation rather than a confusing nasm error.
PLATFORM="amd64"
DO_BUILD=0
FORCE_BUILD=0
RUN_CHECK=0
RUN_TEST=""
CMD=""

usage() {
    cat <<EOF
Usage: ./run.sh [options] [-- command...]

Options:
  --build           build the image if it is missing
  --rebuild         force a rebuild even if the image exists
  --check           run check-env inside the container and exit
  --test            build and run the test suite, then exit
  --valgrind        run the test suite under valgrind, then exit
  --fish            start fish instead of bash
  --platform ARCH   accepted for symmetry with ft_ping; amd64 only
  -h, --help        this message

Examples:
  ./run.sh --build --check          # first-time setup and verification
  ./run.sh                          # interactive shell in /workspace
  ./run.sh --test                   # one-shot test run
  ./run.sh -- make -C tests test ARGS="-v strlen"
EOF
}

START_CMD="/bin/bash"

while [ $# -gt 0 ]; do
    case "$1" in
        --platform) PLATFORM="${2:-}"; shift 2 ;;
        --build)    DO_BUILD=1; shift ;;
        --rebuild)  DO_BUILD=1; FORCE_BUILD=1; shift ;;
        --check)    RUN_CHECK=1; DO_BUILD=1; shift ;;
        --test)     RUN_TEST="test"; DO_BUILD=1; shift ;;
        --valgrind) RUN_TEST="valgrind"; DO_BUILD=1; shift ;;
        --fish)     START_CMD="/usr/bin/fish"; shift ;;
        -h|--help)  usage; exit 0 ;;
        --)         shift; CMD="$*"; break ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

case "$PLATFORM" in
    amd64|native) PLATFORM="amd64" ;;
    arm64)
        cat >&2 <<'EOF'
libasm is 64-bit x86 assembly (nasm -f elf64). An arm64 container cannot
assemble or run any of it, so there is no arm64 image to build.

This is the one place libasm differs from ft_ping: there, arm64 was the fast
native daily driver. Here everything runs emulated on an Apple Silicon Mac.
If valgrind fails under emulation, see README.md -> "When valgrind won't run".
EOF
        exit 1 ;;
    *) echo "--platform must be amd64 (got: $PLATFORM)" >&2; exit 1 ;;
esac

command -v docker >/dev/null || { echo "docker not found on PATH" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "docker daemon not reachable — is Docker Desktop running?" >&2; exit 1; }

EMULATED=0
[ "$PLATFORM" != "$NATIVE_ARCH" ] && EMULATED=1

if [ "$DO_BUILD" -eq 1 ]; then
    if [ "$FORCE_BUILD" -eq 1 ] || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
        echo ">> building $IMAGE (linux/$PLATFORM)"
        [ "$EMULATED" -eq 1 ] && echo "   emulated build — this will take a while"
        docker build --platform "linux/$PLATFORM" -t "$IMAGE" "$SCRIPT_DIR"
    fi
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "image $IMAGE not found. Run: ./run.sh --build" >&2
    exit 1
fi

echo ">> host: $HOST_OS/$NATIVE_ARCH   container: linux/$PLATFORM$([ "$EMULATED" -eq 1 ] && echo "  (emulated)")"
if [ "$EMULATED" -eq 1 ] && [ "$HOST_OS" = "Darwin" ]; then
    echo ">> note: valgrind is unreliable under x86_64 emulation on Apple Silicon,"
    echo "         and libasm has no native fallback. Run --check to find out where"
    echo "         you stand; README.md has the real-VM workaround."
fi

# --cap-add=SYS_PTRACE          gdb and valgrind both need to trace the process
# --security-opt seccomp=unconfined  the default seccomp profile blocks some of
#                               what valgrind and ptrace want; this is a local dev
#                               box on your own code, not a sandbox for untrusted
#                               binaries, so the trade is worth it
# HOST_ARCH                     lets check-env report emulation accurately instead
#                               of guessing from /proc
DOCKER_ARGS="--rm --platform linux/$PLATFORM \
    --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
    -e HOST_ARCH=$NATIVE_ARCH \
    -v $PROJECT_ROOT:/workspace -w /workspace"

# shellcheck disable=SC2086  # DOCKER_ARGS is intentionally word-split
if [ "$RUN_CHECK" -eq 1 ]; then
    exec docker run $DOCKER_ARGS "$IMAGE" check-env
elif [ -n "$RUN_TEST" ]; then
    exec docker run -it $DOCKER_ARGS "$IMAGE" make -C tests "$RUN_TEST"
elif [ -n "$CMD" ]; then
    exec docker run -it $DOCKER_ARGS "$IMAGE" /bin/bash -lc "$CMD"
else
    exec docker run -it $DOCKER_ARGS "$IMAGE" "$START_CMD"
fi
