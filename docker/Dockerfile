# libasm test environment — matches the 42 evaluation platform (Debian/Ubuntu + glibc).
#
# x86_64 ONLY, and that is not a preference. The subject mandates 64-bit x86
# assembly, so an arm64 image cannot assemble a single line of this project. Unlike
# ft_ping — where arm64 was the fast native daily driver and amd64 was the pre-eval
# parity check — here there is no native option on an Apple Silicon Mac. Everything
# runs emulated, and the one tool that genuinely suffers for it is valgrind.
# check-env reports on that explicitly; see README.md for the escape hatch.
#
# Do NOT swap this for Alpine. libasm calls into libc by name — `malloc wrt ..plt`,
# `__errno_location wrt ..plt` — and musl's symbol set, PLT behaviour and errno
# implementation are not the glibc ones you are graded against. "Lighter" is the
# wrong axis to optimise.
#
# Pinned, not :latest — a floating base tag means your environment silently changes
# under you mid-project, which is the opposite of what a test environment is for.
FROM ubuntu:22.04
ARG TARGETARCH
LABEL org.opencontainers.image.title="libasm test environment" \
      org.opencontainers.image.description="glibc x86_64 Linux for 42 libasm (NASM)" \
      libasm.arch="${TARGETARCH}"

ARG DEBIAN_FRONTEND=noninteractive

# Toolchain + the diagnostic tools assembly work actually calls for.
#   nasm          the assembler the subject mandates (-f elf64)
#   build-essential  gcc/ld/ar/make — you link .o files into libasm.a and then
#                 into a C driver, so the C toolchain is not optional
#   binutils      nm / objdump / readelf: reading your own object files is most of
#                 how you debug a symbol that "isn't there"
#   gdb           stepping instruction by instruction is how you debug assembly;
#                 layout regs + si is the core loop. Needs --cap-add=SYS_PTRACE.
#   valgrind      ft_strdup allocates, so leaks are gradeable. See the note above.
#   strace        proves what your raw `syscall` instruction actually asked the
#                 kernel for, which is faster than guessing at register order
#   ltrace        shows the malloc/free calls your asm makes through the PLT
#   clang         -fsanitize=address as the fallback when valgrind can't run
#   cppcheck      lints the C test drivers, not the asm
#   patchelf/file/xxd  inspecting the binaries you produce
#   fish          requested as the interactive shell; bash stays the CMD-safe default
RUN apt-get update && apt-get install -y --no-install-recommends \
        nasm \
        build-essential \
        make \
        binutils \
        libc6-dev \
        gdb \
        valgrind \
        strace \
        ltrace \
        clang \
        cppcheck \
        patchelf \
        file \
        xxd \
        bsdmainutils \
        python3 \
        ripgrep \
        tree \
        curl \
        ca-certificates \
        git \
        vim \
        nano \
        less \
        man-db \
        fish \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Fail loudly and early if the assembly toolchain is broken, instead of letting you
# debug an emulation problem as if it were a bug in your code.
COPY check-env.sh /usr/local/bin/check-env
RUN chmod +x /usr/local/bin/check-env

# Interactive niceties for fish. Deliberately not the CMD: scripts and `run.sh -- cmd`
# expect a POSIX shell, so bash stays the default and fish is opt-in.
COPY fish/config.fish /root/.config/fish/config.fish

# Empty on purpose — a leak you suppressed is a leak you still have at defense.
COPY valgrind.supp /etc/valgrind/libasm.supp
ENV VALGRIND_OPTS="--suppressions=/etc/valgrind/libasm.supp"

CMD ["/bin/bash"]
