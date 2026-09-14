# Libasm Lessons — Overview

This is the full course, split into one file per phase so each phase is a clean,
self-contained read. Work through them in order — later phases assume you've
internalized the earlier ones, especially Phases 2, 4, and 5.

Every phase file follows the same shape:

1. **Plain-English first** — the idea explained with zero jargon, usually via an
   analogy, before any technical vocabulary shows up.
2. **Now with the real terms** — the same idea, re-explained using the actual
   vocabulary you'll see in documentation, code, and your defense.
3. **Deep dive** — the full mechanics: the details that actually matter for
   writing correct code.
4. **Checkpoint** — questions with collapsed answers (click to expand) so you can
   honestly self-test before moving on.

## Reading order

| # | File | Topic |
|---|------|-------|
| 1 | `01-how-a-cpu-executes.md` | What a CPU is actually doing |
| 2 | `02-registers.md` | The x86-64 register set |
| 3 | `03-nasm-syntax.md` | NASM/Intel syntax and core instructions |
| 4 | `04-calling-convention.md` | The System V AMD64 ABI (the crux of the project) |
| 5 | `05-syscalls.md` | Linux syscalls on x86-64 |
| 6 | `06-errno.md` | errno and calling external C functions |
| 7 | `07-toolchain.md` | nasm / ld / ar / Makefile mechanics |
| 8 | `08-practice-programs.md` | Tiny standalone programs before the real project |
| 9 | `09-mandatory-functions.md` | Implementing the six required functions |
| 10 | `10-testing.md` | Testing strategy |
| 11 | `11-bonus.md` | ft_atoi_base and the linked-list functions |
| 12 | `12-defense-readiness.md` | Tying it all together for the oral defense |

## How to actually use this

Don't speed-read. For each file: read the plain-English section, read the deep
dive, then close the file (or scroll away) and try to answer the checkpoint
questions from memory before expanding the answers. If you can't answer one
without peeking, that's the signal to reread — not to move on and hope it clicks
later. This project's bugs are almost always traceable to a shaky Phase 2, 4, or 5,
so it's worth being stubborn about those three specifically.
