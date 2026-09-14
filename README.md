# libasm

A 42 School project: reimplementing a handful of libc functions in **x86-64
assembly** (NASM, Intel syntax, System V AMD64 ABI), packaged as a static
library `libasm.a`.

This repo contains two things, and the second one is probably why you're here:

1. **The library** — the assembly, a Makefile, a test harness, and a container
   to run it all in.
2. **[`lessons/`](lessons/) — a full written course on x86-64 assembly**, from
   "what is a register, physically" up to the calling-convention details this
   project actually breaks on. Written while learning the project, for the
   version of me who didn't know any of it yet. Free for anyone to read.

---

## The lessons

Twelve phases, each a self-contained read. Every file follows the same shape:
plain-English explanation first (no jargon, usually an analogy), then the same
idea in real terminology, then the full mechanics, then checkpoint questions with
collapsed answers so you can honestly self-test before moving on.

| # | File | Topic |
|---|------|-------|
| 0 | [`00-overview.md`](lessons/00-overview.md) | How to use the course |
| 1 | [`01-how-a-cpu-executes.md`](lessons/01-how-a-cpu-executes.md) | What a CPU is actually doing |
| 2 | [`02-registers.md`](lessons/02-registers.md) | The x86-64 register set |
| 3 | [`03-nasm-syntax.md`](lessons/03-nasm-syntax.md) | NASM/Intel syntax and core instructions |
| 4 | [`04-calling-convention.md`](lessons/04-calling-convention.md) | The System V AMD64 ABI — the crux of the project |
| 5 | [`05-syscalls.md`](lessons/05-syscalls.md) | Linux syscalls on x86-64 |
| 6 | [`06-errno.md`](lessons/06-errno.md) | errno, and calling C functions from asm |
| 7 | [`07-toolchain.md`](lessons/07-toolchain.md) | nasm / ld / ar / Makefile mechanics |
| 8 | [`08-practice-programs.md`](lessons/08-practice-programs.md) | Tiny standalone programs before the real thing |
| 9 | [`09-mandatory-functions.md`](lessons/09-mandatory-functions.md) | Implementing the six required functions |
| 10 | [`10-testing.md`](lessons/10-testing.md) | Testing strategy |
| 11 | [`11-bonus.md`](lessons/11-bonus.md) | `ft_atoi_base` and the linked-list functions |
| 12 | [`12-defense-readiness.md`](lessons/12-defense-readiness.md) | Tying it together for the oral defense |

Alongside them: [`LEARNING_PLAN.md`](LEARNING_PLAN.md) is the phase-by-phase
checklist, and [`REGISTER_CHEATSHEET.md`](REGISTER_CHEATSHEET.md) is the
one-pager to keep open while writing code.

If you're starting libasm from zero, read phases 1–7 before writing a line.
Nearly every bug in this project traces back to a shaky understanding of
phase 2, 4 or 5.

---

## The library

### Mandatory

| Function | Signature | The part that's easy to get wrong |
|---|---|---|
| `ft_strlen` | `size_t ft_strlen(const char *s)` | reading past the terminating NUL |
| `ft_strcpy` | `char *ft_strcpy(char *dst, const char *src)` | returns `dst`; must copy the NUL and nothing more |
| `ft_strcmp` | `int ft_strcmp(const char *s1, const char *s2)` | bytes compare as **unsigned** char; only the sign is specified |
| `ft_write` | `ssize_t ft_write(int fd, const void *buf, size_t n)` | on failure: return `-1` **and** set `errno` |
| `ft_read` | `ssize_t ft_read(int fd, void *buf, size_t n)` | same, plus `0` at EOF is success, not failure |
| `ft_strdup` | `char *ft_strdup(const char *s)` | calls `malloc` — the real calling-convention test |

### Bonus

| Function | Signature |
|---|---|
| `ft_atoi_base` | `int ft_atoi_base(char *str, char *base)` |
| `ft_list_push_front` | `void ft_list_push_front(t_list **begin, void *data)` |
| `ft_list_size` | `int ft_list_size(t_list *begin)` |
| `ft_list_sort` | `void ft_list_sort(t_list **begin, int (*cmp)())` |
| `ft_list_remove_if` | `void ft_list_remove_if(t_list **begin, void *ref, int (*cmp)(), void (*free_fct)(void *))` |

### Status

- [x] `ft_strlen`
- [x] `ft_strcpy`
- [x] `ft_strcmp`
- [ ] `ft_write`
- [ ] `ft_read`
- [ ] `ft_strdup`
- [ ] bonus

---

## Build and test

**On Linux x86-64:**

```sh
make            # assemble srcs/ into libasm.a
make bonus      # libasm_bonus.a (mandatory + bonus)
make test       # build and run the test harness
make valgrind   # the same suite under valgrind
make help       # every target
```

**On anything else — macOS included:**

libasm is x86-64 assembly. macOS can't link or run Linux ELF objects, and an
arm64 Mac can't execute x86-64 instructions natively at all. There's a container
for exactly this:

```sh
cd docker
./run.sh --build --check      # build the image, then verify it
./run.sh                      # shell in /workspace, your files bind-mounted
./run.sh --test               # one-shot test run
```

`make env` reports your toolchain and answers the only question that matters:
*can this machine run what it assembles?* See
[`docker/README.md`](docker/README.md) for the details, including the one thing
that genuinely breaks under x86-64 emulation on Apple Silicon (valgrind) and how
to work around it.

Using the library from your own C:

```sh
gcc main.c libasm.a -o prog
```

---

## Layout

```
srcs/string/      ft_strlen ft_strcpy ft_strcmp ft_strdup
srcs/io/          ft_write ft_read
srcs/bonus/       ft_atoi_base, the list functions
includes/         libasm.h — C prototypes
tests/            C test harness (weak-linked; see below)
docker/           x86-64 container: Dockerfile, run.sh, check-env.sh
lessons/          the written course
assets/           diagrams the lessons reference
Makefile          sources are discovered, not listed — drop a .s in and it builds
```

---

## The test harness

`tests/` builds `libasm.a`, links it with `--whole-archive`, and compares each
`ft_*` against its libc equivalent. Every `ft_*` is declared **weak**, so
functions that don't exist yet report `skip` instead of breaking the link — the
suite is useful from the very first function onward.

```sh
make test                          # everything
make test ARGS="-v strlen"         # one suite, verbose
make symbols                       # what libasm.a exports, and what it calls out to
make disasm FN=ft_strlen           # Intel-syntax disassembly of one function
make check                         # strict nasm warnings + .note.GNU-stack audit
```

Beyond checking return values, it tests the things that pass on a normal heap
string and fail in production:

- **Page-boundary over-reads.** `ft_strlen` and `ft_strcmp` get called on a
  string whose NUL is the last readable byte before an unmapped page. Read one
  byte too far and you fault. The suite catches the fault and reports it as an
  ordinary failure instead of dying — this is the bug a multi-byte-at-a-time
  loop hides.
- **Unsigned comparison** in `ft_strcmp`, with `\x80` and `\xff` inputs. Only
  the *sign* is compared against libc, which is all the subject specifies.
- **Canary walls** after `ft_strcpy`'s destination, at every length 0–300.
- **errno in both directions**: a bad fd must give `-1` *and* `EBADF`, and a
  *successful* call must not clobber `errno`.
- **`ft_strdup` under valgrind**, 400 lengths allocated and freed.

---

## Notes if you're attempting this project

Five things that cost real time, in rough order of how much:

1. **Stack alignment.** `rsp` must be 16-byte aligned at every `call`. On entry
   to your function it is *not* — the caller's `call` pushed 8 bytes. One `push`
   fixes it; two don't. Get this wrong and `malloc` segfaults somewhere deep
   inside libc, nowhere near your bug.
2. **Call through the PLT.** `call malloc wrt ..plt`, not `call malloc`. Modern
   toolchains default to position-independent executables, and a direct call
   fails to link.
3. **errno is a function, not a variable.** It's thread-local; you get its
   address from `__errno_location` and write to `[rax]`.
4. **`strcmp` compares unsigned bytes.** `movzx`, not `movsx`. `"\x80"` is
   greater than `"\x7f"`, and signed comparison silently gets this backwards
   for every high-bit byte.
5. **Declare a non-executable stack** in each `.s` file, or the linker warns
   forever:
   ```asm
   section .note.GNU-stack noalloc noexec nowrite progbits
   ```

---

## Notes

The 42 subject PDF isn't included — it isn't mine to redistribute. The lessons
are my own writing and you're welcome to them.
