# Libasm Learning Plan

Bottom-up path from zero assembly knowledge to a finished 42 `libasm` project.
No code is written until Phase 8 (throwaway practice programs) — Phases 1-7 are pure
concepts, done deliberately before touching the actual project files.

---

## Phase 1 — How a CPU actually executes something
- [ ] Understand what a CPU register physically is
- [ ] Understand memory as flat address space (no types, just bytes)
- [ ] Understand the instruction pointer / program counter
- [ ] Understand the stack vs the heap at the hardware level
- [ ] Understand "a program is just a sequence of instructions operating on registers and memory"

## Phase 2 — x86-64 register set
- [ ] Know the general-purpose registers: `rax rbx rcx rdx rsi rdi rbp rsp r8-r15`
- [ ] Know sub-register views: `rax / eax / ax / al`
- [ ] Know `rsp` (stack pointer) and `rbp` (base pointer) specifically
- [ ] Understand the flags register conceptually (zero flag, carry flag, sign flag)

## Phase 3 — NASM syntax and core instructions
- [ ] Understand Intel syntax structure (`dest, src` order)
- [ ] Know sections: `.text`, `.data`, `.bss`
- [ ] Know `global` / `extern` directives
- [ ] Know `mov`, `lea`
- [ ] Know `add`, `sub`
- [ ] Know `cmp`, `test`
- [ ] Know conditional jumps: `je`, `jne`, `jl`, `jg`, `jle`, `jge`
- [ ] Know unconditional `jmp`
- [ ] Know `push`, `pop`
- [ ] Know `call`, `ret`

## Phase 4 — The calling convention (crux of the project)
- [ ] Learn System V AMD64 ABI argument order: `rdi, rsi, rdx, rcx, r8, r9`
- [ ] Learn return value convention (`rax`)
- [ ] Learn caller-saved vs callee-saved registers
- [ ] Learn 16-byte stack alignment rule before `call`
- [ ] Learn function prologue/epilogue (`push rbp` / `mov rbp, rsp` / leave)
- [ ] Be able to explain why misaligned stack breaks calls to libc functions

## Phase 5 — Linux syscalls on x86-64
- [ ] Learn how the `syscall` instruction works
- [ ] Learn syscall number goes in `rax`
- [ ] Learn syscall argument registers: `rdi, rsi, rdx, r10, r8, r9` (note: `r10` not `rcx`)
- [ ] Learn syscall return value convention and negative-value error signaling
- [ ] Look up syscall numbers for `write` and `read`
- [ ] Understand difference between a raw syscall and a libc wrapper

## Phase 6 — errno and calling external symbols
- [ ] Understand how errno works (thread-local storage)
- [ ] Learn how to call `__errno_location` from assembly
- [ ] Understand calling a C-ABI function from asm and writing into memory it returns

## Phase 7 — Toolchain mechanics
- [ ] Understand what `nasm` does (`.s` → `.o`)
- [ ] Understand what `ld` and `ar` do
- [ ] Understand a `.a` static library as an archive of `.o` files
- [ ] Understand how a C `main` links against assembled objects
- [ ] Write Makefile rules: `$(NAME)`, `all`, `clean`, `fclean`, `re`
- [ ] Makefile only recompiles changed `.s` files

## Phase 8 — Tiny throwaway programs first
- [ ] Write a standalone `.s` that exits with a custom code via `exit` syscall
- [ ] Write a standalone `.s` that prints "hello world" via `write` syscall
- [ ] Write a standalone `.s` loop that counts up
- [ ] Get comfortable with assemble → link → run cycle
- [ ] Step through a program instruction-by-instruction in gdb/lldb

## Phase 9 — Mandatory functions (easiest to hardest)
- [ ] `ft_strlen` — pure loop, no syscalls, no errors
- [ ] `ft_strcmp` — loop + comparison + return value semantics
- [ ] `ft_strcpy` — loop + memory writes
- [ ] `ft_write` — syscall + error checking + errno
- [ ] `ft_read` — syscall + error checking + errno
- [ ] `ft_strdup` — strlen + strcpy + external `malloc` call (real calling-convention test)
- [ ] Write the C `main` that links against the library and demonstrates it works

## Phase 10 — Testing
- [ ] Cross-check each function against real libc equivalents
- [ ] Test empty strings, single-char strings, huge buffers
- [ ] Test null pointers where applicable
- [ ] Test syscall failure paths (e.g. writing to a bad fd) and verify errno

## Phase 11 — Bonus (only after mandatory is airtight)
- [ ] `ft_atoi_base` — string parsing + base validation
- [ ] `ft_list_push_front` — struct field offsets (`data`, `next`)
- [ ] `ft_list_size`
- [ ] `ft_list_sort` — calling a function pointer passed as an argument
- [ ] `ft_list_remove_if` — calling two function pointers (`cmp`, `free_fct`)

## Phase 12 — Defense readiness
- [ ] Explain why `-no-pie` is forbidden (PIC / ASLR)
- [ ] Explain why the calling convention matters
- [ ] Explain how errno gets set
- [ ] Explain what happens on syscall failure

---

### Reference tools to keep open
- System V ABI register-passing table (cheat sheet)
- Linux x86-64 syscall table
- Compiler Explorer (godbolt.org), gcc, `-O0` — see real asm output for simple C functions (don't copy, just study)
