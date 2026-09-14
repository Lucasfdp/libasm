#!/usr/bin/env bash
# Smoke test for the libasm container. Run this FIRST, before blaming your code.
#
# Exits non-zero if anything that would stop libasm working is broken, so it can
# be used in a Makefile target or CI step, not just read by a human.
set -uo pipefail

pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }
warn() { printf '  \033[33mwarn\033[0m %s\n' "$1"; }
note() { printf '       %s\n' "$1"; }
FAILED=0
T=/tmp/_libasm_check
mkdir -p "$T"

echo "libasm environment check"
echo

# --- platform ----------------------------------------------------------------
# For libasm this is not a preference, it is the whole point. The subject mandates
# 64-bit x86 assembly; an arm64 container cannot assemble a single line of it.
echo "platform"
ARCH="$(uname -m)"
printf '  container arch: %s   ' "$ARCH"
case "$ARCH" in
    x86_64)  echo "(correct — libasm is x86_64 NASM)" ;;
    aarch64) echo "(WRONG)" ;;
    *)       echo "(unexpected)" ;;
esac
if [ "$ARCH" != "x86_64" ]; then
    fail "container is not x86_64 — nasm -f elf64 code cannot run here"
    note "rebuild with --platform amd64; there is no arm64 variant of this project"
fi

# Emulation detection. run.sh passes HOST_ARCH in; fall back to heuristics if the
# container was started by hand.
EMULATED="no"
if [ "${HOST_ARCH:-}" = "arm64" ] && [ "$ARCH" = "x86_64" ]; then EMULATED="yes"; fi
[ -e /proc/sys/fs/binfmt_misc/rosetta ] && EMULATED="rosetta"
grep -qsi qemu /proc/cpuinfo && EMULATED="qemu"
if [ "$EMULATED" != "no" ]; then
    note "running under x86_64 emulation ($EMULATED) — see the valgrind section below"
fi

LIBC_VER="$(ldd --version 2>/dev/null | sed -n '1p')"
printf '  libc: %s\n' "${LIBC_VER:-unknown}"
if printf '%s' "$LIBC_VER" | grep -qi musl; then
    fail "musl libc detected — this image must be glibc-based"
    note "libasm calls malloc and __errno_location by name; keep the libc matching"
    note "the evaluation machine (Debian/Ubuntu), not Alpine"
else
    pass "glibc (matches the evaluation platform)"
fi

# Default-PIE matters: it decides whether `call malloc wrt ..plt` is required or
# merely allowed, and it is the usual reason asm that links at 42 fails here.
if gcc -v 2>&1 | grep -q -- '--enable-default-pie'; then
    pass "gcc defaults to PIE (same as the 42 machines) — use 'wrt ..plt' on calls"
else
    warn "gcc does NOT default to PIE here — your asm may link here and fail at 42"
fi
echo

# --- toolchain ---------------------------------------------------------------
echo "toolchain"
for t in nasm gcc ld ar nm objdump readelf make gdb; do
    command -v "$t" >/dev/null && pass "$t" || fail "$t missing"
done
if command -v nasm >/dev/null; then
    printf '       %s\n' "$(nasm -v)"
    if nasm -hf 2>&1 | grep -q 'elf64'; then
        pass "nasm supports -f elf64"
    else
        fail "nasm cannot emit elf64 — wrong build of nasm"
    fi
fi
echo

# --- the thing that actually matters -----------------------------------------
# Assemble, link and RUN real assembly. A toolchain that is merely *installed*
# proves nothing; this proves the whole path works end to end.
echo "assembling and running x86_64 assembly"
cat > "$T/basic.s" <<'EOF'
section .text
global main
main:
	mov eax, 42
	ret
section .note.GNU-stack noalloc noexec nowrite progbits
EOF
if nasm -f elf64 -g -F dwarf "$T/basic.s" -o "$T/basic.o" 2>"$T/err"; then
    pass "nasm -f elf64 assembles"
    if gcc "$T/basic.o" -o "$T/basic" 2>>"$T/err"; then
        pass "gcc links a NASM object"
        "$T/basic"; RC=$?
        if [ "$RC" -eq 42 ]; then
            pass "the binary runs and returns the right value"
        else
            fail "binary ran but returned $RC instead of 42"
        fi
    else
        fail "linking failed"; sed 's/^/       /' "$T/err"
    fi
else
    fail "assembling failed"; sed 's/^/       /' "$T/err"
fi

# The three libc interactions every libasm function set depends on:
# a PLT call, a malloc/free round trip, and errno via __errno_location.
cat > "$T/probe.s" <<'EOF'
section .text
extern malloc
extern free
extern __errno_location
global asm_probe
asm_probe:
	push rbp
	mov rbp, rsp
	mov rdi, 32
	call malloc wrt ..plt
	test rax, rax
	je .fail
	mov rdi, rax
	call free wrt ..plt
	call __errno_location wrt ..plt
	mov dword [rax], 7
	xor eax, eax
	leave
	ret
.fail:
	mov eax, 1
	leave
	ret

global asm_write
asm_write:
	mov rax, 1
	syscall
	ret
section .note.GNU-stack noalloc noexec nowrite progbits
EOF
cat > "$T/probe.c" <<'EOF'
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
int asm_probe(void);
long asm_write(int fd, const void *buf, unsigned long n);
int main(void) {
	int fd;
	errno = 0;
	if (asm_probe()) return 1;
	if (errno != 7) return 2;
	fd = open("/dev/null", O_WRONLY);
	if (asm_write(fd, "xyz", 3) != 3) return 3;
	if (asm_write(-1, "x", 1) != -9) return 4;   /* raw syscall returns -EBADF */
	return 0;
}
EOF
if nasm -f elf64 "$T/probe.s" -o "$T/probe_asm.o" 2>"$T/err" \
   && gcc "$T/probe.c" "$T/probe_asm.o" -o "$T/probe" 2>>"$T/err"; then
    "$T/probe"; RC=$?
    case "$RC" in
        0) pass "PLT calls, malloc/free and __errno_location all work from asm"
           pass "the syscall instruction works (raw write + raw -EBADF)" ;;
        1) fail "malloc via 'call malloc wrt ..plt' returned NULL" ;;
        2) fail "__errno_location did not give a writable errno slot" ;;
        3) fail "the syscall instruction did not perform a write" ;;
        4) fail "syscall error convention is wrong (expected -EBADF in rax)"
           note "under some emulators raw syscalls behave differently than on real Linux" ;;
        *) fail "asm probe crashed (exit $RC)" ;;
    esac
else
    fail "could not build the PLT/errno/syscall probe"; sed 's/^/       /' "$T/err"
fi
echo

# --- memory checking ---------------------------------------------------------
# This is the one that decides whether the container is good enough on its own.
echo "memory checking"
if command -v valgrind >/dev/null; then
    printf '       %s\n' "$(valgrind --version)"
    if [ -x "$T/probe" ] && valgrind -q --error-exitcode=99 "$T/probe" >"$T/vg" 2>&1; then
        pass "valgrind runs real assembly correctly"
    elif valgrind --error-exitcode=99 /bin/true >/dev/null 2>&1; then
        warn "valgrind runs trivial programs but failed on the asm probe"
        sed 's/^/       /' "$T/vg" | head -8
    else
        fail "valgrind cannot run here"
        if [ "$EMULATED" != "no" ]; then
            note "expected: valgrind's dynamic recompilation conflicts with Rosetta"
            note "and QEMU user-mode emulation. Unlike ft_ping there is no native"
            note "arm64 fallback — libasm has to be x86_64."
            note "Options: (1) a real x86_64 VM —"
            note "    colima start --arch x86_64 --vm-type qemu --cpu 4 --memory 6"
            note "    docker context use colima && ./run.sh --rebuild --check"
            note "  (2) -fsanitize=address on the C test driver, checked below."
        fi
    fi
else
    fail "valgrind missing"
fi

echo 'int main(void){return 0;}' > "$T/asan.c"
if gcc -fsanitize=address "$T/asan.c" -o "$T/asan" 2>/dev/null && "$T/asan" 2>/dev/null; then
    pass "AddressSanitizer available (works under emulation too)"
else
    warn "AddressSanitizer unavailable"
fi
echo

# --- debugger ----------------------------------------------------------------
# gdb needs ptrace, which needs --cap-add=SYS_PTRACE. Stepping through your own
# instructions is most of how you debug assembly, so this is not optional.
echo "debugger"
if [ -x "$T/basic" ] && gdb -batch -ex run -ex quit "$T/basic" >"$T/gdb" 2>&1; then
    pass "gdb can run a process (ptrace works)"
else
    if grep -qi 'operation not permitted\|ptrace' "$T/gdb" 2>/dev/null; then
        fail "gdb cannot ptrace — add --cap-add=SYS_PTRACE to docker run"
    else
        warn "gdb did not complete a batch run"
        sed 's/^/       /' "$T/gdb" 2>/dev/null | head -5
    fi
fi
if command -v gdb >/dev/null && gdb -batch -ex 'set disassembly-flavor intel' -ex quit >/dev/null 2>&1; then
    pass "gdb accepts Intel disassembly flavour"
fi
echo

# --- workspace ---------------------------------------------------------------
echo "workspace"
if [ -d /workspace ]; then
    if touch /workspace/.libasm_write_test 2>/dev/null; then
        rm -f /workspace/.libasm_write_test
        pass "/workspace is writable (bind mount is live)"
    else
        fail "/workspace is not writable — check the -v bind mount"
    fi
    # The cross-platform artifact trap: objects built on macOS are Mach-O and will
    # not link here, but make only compares timestamps and will try anyway.
    STALE=$(find /workspace -maxdepth 3 \( -name '*.o' -o -name '*.a' \) 2>/dev/null | head -50)
    BAD=""
    for f in $STALE; do
        file -b "$f" 2>/dev/null | grep -qi 'mach-o\|arm64\|aarch64' && BAD="$BAD $f"
    done
    if [ -n "$BAD" ]; then
        fail "non-x86_64 object files in the bind mount:$BAD"
        note "these were built on macOS or on an arm64 image. Run 'make fclean'"
        note "(and 'make -C tests fclean') before building in here."
    else
        pass "no foreign object files left in the tree"
    fi
else
    warn "/workspace missing — started without the bind mount?"
fi
echo

# --- extras ------------------------------------------------------------------
echo "extras"
for t in fish rg strace ltrace cppcheck xxd; do
    command -v "$t" >/dev/null && pass "$t" || warn "$t missing"
done
echo

rm -rf "$T"

if [ "$FAILED" -eq 0 ]; then
    echo "environment looks good."
else
    echo "environment has problems — fix these before writing code."
    exit 1
fi
