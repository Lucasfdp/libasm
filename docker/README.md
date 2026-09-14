# libasm test container

A glibc **x86_64** Linux environment matching the 42 evaluation platform, with the
full NASM toolchain and a test suite that diffs your assembly against libc.

## Quick start

```sh
cd docker
./run.sh --build --check      # build the image and verify it
./run.sh                      # interactive shell in /workspace
./run.sh --test               # one-shot test run
```

Or via make, if you prefer:

```sh
make build && make check
make shell
```

`run.sh` finds the project root itself, so you can invoke it from anywhere.

---

## Which platform should I use?

There is no choice to make, and that is the one real difference from the ft_ping
setup. libasm is **64-bit x86 assembly** — `nasm -f elf64`. An arm64 container
cannot assemble a single line of it, so `--platform arm64` doesn't exist here; it
prints an explanation and exits.

On your M2 that means **everything runs emulated**, all the time.

| | libasm (here) | ft_ping |
|---|---|---|
| Native arm64 image | impossible — x86 asm | daily driver |
| Emulated amd64 | the only option | pre-eval spot check |
| Speed | slow-ish; fine for a library this size | — |
| glibc headers / symbols | identical to eval | identical |
| valgrind | **may not run** — see below | worked natively |

The good news: libasm builds in under a second, so emulation overhead barely
registers. Docker Desktop → Settings → General → **Use Rosetta for x86_64/amd64
emulation** makes it faster still.

---

## When valgrind won't run

Both Rosetta and QEMU user-mode conflict with valgrind's dynamic recompilation.
ft_ping could dodge this by doing memory checks on the native arm64 image. **libasm
cannot** — it has to be x86_64, so if valgrind is broken under your emulator, it's
broken everywhere in this container.

`./run.sh --check` tells you which situation you're in: it runs valgrind against a
real assembled binary that mallocs and frees, not just `/bin/true`.

If it fails, use a real x86_64 VM instead of emulation:

```sh
brew install colima docker
colima start --arch x86_64 --vm-type qemu --cpu 4 --memory 6 --disk 30
docker context use colima
cd docker && ./run.sh --rebuild --check
```

That's a genuine x86_64 kernel, so valgrind, gdb and strace behave exactly as they
do on a 42 iMac. Builds are slower. Switch back with
`docker context use desktop-linux`.

Interim fallback: `-fsanitize=address` on the C test driver works under emulation
and catches overflows and use-after-free, though not leaks as thoroughly.

---

## First thing, every session

```sh
./run.sh --check
```

Verifies, in order: the container is x86_64; glibc not musl; gcc's default-PIE
setting (which decides whether `wrt ..plt` is required); nasm can emit elf64; a
real `.s` file assembles, links and returns the right exit code; `malloc`, `free`
and `__errno_location` all work through the PLT from assembly; the raw `syscall`
instruction works and returns `-EBADF` the way the kernel really does; valgrind runs
*that* binary; gdb can ptrace; the bind mount is writable; and no Mach-O or arm64
object files are lying around in the tree.

**Run this before concluding you have a bug.** An emulation problem that looks like
a logic bug will cost you an afternoon. It exits non-zero on failure, so you can
wire it into CI.

---

## The test suite

`tests/` lives at the project root, not in here. It builds `libasm.a`, links it with
`--whole-archive`, and compares each `ft_*` against libc.

```sh
./run.sh --test                            # everything
./run.sh --valgrind                        # everything, under valgrind
./run.sh -- make -C tests test ARGS="-v strlen"   # one suite, verbose
./run.sh -- make -C tests symbols          # what libasm.a exports right now
```

Every `ft_*` is declared **weak**, so functions you haven't written yet report
`skip` instead of breaking the build — the suite is useful from your first function
onward. It uses your own `Makefile` if the project root has one, and otherwise
assembles every `.s` it finds itself.

Beyond the obvious, it checks:

- **Page-boundary over-reads.** `ft_strlen` and `ft_strcmp` are called on a string
  whose NUL is the last byte before an unmapped page. Read one byte too far and you
  fault; the suite catches the fault and reports a normal FAIL. This is the bug a
  multi-byte-at-a-time loop hides on ordinary heap strings.
- **Unsigned byte comparison** in `ft_strcmp`, with `\x80`/`\xff` inputs. Only the
  *sign* is compared against libc, which is all the subject requires.
- **Canary walls** after `ft_strcpy`'s destination, at every length 0..300.
- **errno in both directions**: a bad fd must give `-1` + `EBADF`, *and* a
  successful call must not clobber `errno`.
- Bonus: `ft_atoi_base` base-validity rules, sign stacking, `INT_MIN`; the list
  functions including empty-list and remove-the-head.

---

## Gotchas

**Build artifacts collide across platforms.** The bind mount is shared between macOS
and the container. `make` compares timestamps, not architectures — so it will
happily try to link a Mach-O object against an ELF one and fail confusingly.
`check-env` now fails loudly when it finds foreign objects, but the fix is yours:
`make fclean && make -C tests fclean`.

**Don't add `--user`.** It costs you the ptrace capability gdb and valgrind need. If
root-owned files on a Linux host bother you, use `make fix-perms`.

**Don't swap to Alpine.** Your assembly calls glibc symbols by name through the PLT.
musl is a different libc with different symbol behaviour, and you are not graded
against it. `check-env` fails loudly if it ever finds musl.

**Add `.note.GNU-stack` to your `.s` files.** Without it the linker warns that your
object implies an executable stack:

```asm
section .note.GNU-stack noalloc noexec nowrite progbits
```

The test Makefile links with `-z noexecstack` so it isn't noisy meanwhile, but the
real fix belongs in the source.

**`--rm` is intentional.** With the toolchain baked into the image, containers are
disposable. Anything worth keeping belongs in the Dockerfile.

---

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | The image. x86_64 only, pinned to ubuntu:22.04. |
| `run.sh` | Launcher. Detects host arch, warns about emulation, wires up ptrace. |
| `check-env.sh` | Smoke test, baked into the image as `check-env`. |
| `Makefile` | Optional convenience targets around `run.sh`. |
| `fish/config.fish` | `t`, `vg`, `nn`, `dis` helpers for the fish shell. |
| `valgrind.supp` | Deliberately empty suppression file. |
| `.dockerignore` | Keeps the build context to what the image copies. |
