# Phase 4 — The Calling Convention (the crux of the project)

This is the single most important phase in the whole course. Nearly every bug
you'll hit later — segfaults inside functions you didn't even write, garbage
return values, crashes that seem to make no sense — traces back to something in
this phase not being respected. Take it slowly.

## Plain-English first

Picture an office with one shared desk (this is the same desk/trays from Phases
1 and 2 — the CPU's registers). Multiple workers (functions) take turns using
this one desk throughout the day. Because they share it, there has to be an
unwritten office etiquette everyone follows, or chaos ensues: whoever leaves a
sticky note in "tray 3" for their coworker, the coworker needs to know to look at
tray 3 for it — not tray 7, not the floor. And when a worker steps away from the
desk temporarily to let a coworker use it, some trays are "fair game" for the
coworker to scribble over and leave messy, while other trays are ones the
coworker has promised to put back exactly as they found them before leaving.

Specifically, in this office: when you want to hand off a task to a coworker
with some input numbers, there's an agreed order of trays you fill first ("first
number goes in tray A, second in tray B," etc.) — so you don't have to explain
that every single time, everyone just knows the order. When the coworker finishes
and hands the result back, there's one specific tray everyone checks for the
answer.

There's also a notepad for temporary overflow (the stack from Phase 1), and it
has a subtle physical requirement: whenever you're about to call a coworker over,
the notepad's current writing position needs to land on specific ruled lines —
not because it's arbitrary pickiness, but because some coworkers use tools
(certain fast built-in calculators) that only work correctly if the notepad is
aligned that way when they start writing. If you hand off to a coworker with the
notepad misaligned, their tool malfunctions — and it looks like *their* mistake
even though you caused it by not aligning things properly before calling them
over.

This entire etiquette — which trays for which argument, which tray for the
answer, which trays a coworker is allowed to scribble on freely versus must
preserve, and the notepad alignment rule — is what the "calling convention" is.
It's not a law of physics. It's an agreed-upon contract. It exists purely so that
code written by different people (you, the C standard library authors, the
compiler) can call each other's functions and actually work, without needing to
read each other's source code first.

## Now with the real terms

This project uses the **System V AMD64 ABI** — the calling convention used on
Linux and macOS for 64-bit x86 code (Windows uses a different one, with
different registers — don't mix references from Windows-focused material).

- **Argument order**: the first six integer/pointer arguments to a function go
  in `rdi, rsi, rdx, rcx, r8, r9`, in that order, matching the order they appear
  in the C prototype left to right. (A 7th+ argument would spill onto the stack
  — not something this project's function signatures require.)
- **Return value**: goes in `rax`. (For values too large to fit in one register,
  `rdx:rax` is used together — not needed for this project.)
- **Caller-saved registers** (also called *volatile*): `rax, rcx, rdx, rsi, rdi,
  r8, r9, r10, r11`. A function you call is allowed to overwrite these freely,
  no questions asked. If *you* (the caller) have a value in one of these that you
  still need *after* a `call`, it's entirely your job to save it first (e.g.
  `push` it before the call, `pop` it after) — the callee owes you nothing here.
- **Callee-saved registers** (also called *non-volatile*): `rbx, rbp, r12, r13,
  r14, r15`. If a function you write uses any of these internally, that
  function must save their original values on entry and restore them before
  returning — because the *caller* is trusting that these specific registers
  come back untouched, regardless of what your function did internally.
- **Stack alignment**: at the moment a `call` instruction executes, `rsp` must
  be a multiple of 16. This is a hard requirement, not a style preference —
  some functions (including parts of libc) use SSE instructions internally that
  fault on misaligned memory access. Because `call` itself pushes an 8-byte
  return address, immediately *inside* the callee (right after entry), `rsp % 16
  == 8`, not 0 — a detail that trips people up when they try to verify alignment
  by eye.
- **Prologue/epilogue**: many functions begin with `push rbp` then `mov rbp,
  rsp` — this saves the caller's frame pointer (since `rbp` is callee-saved) and
  establishes a new stable reference point for the current function. Near the
  end, the reverse happens (restore `rsp`, `pop rbp` or use `leave`) before
  `ret`. Very short leaf functions that don't call anything else and don't need
  a stack frame can sometimes skip this, but once you call out to something
  else, get in the habit of doing it properly.

## Deep dive

- **Why does any of this matter if you're "just" writing a self-contained
  function?** Because almost nothing in this project is truly self-contained:
  `ft_write`/`ft_read` invoke the kernel (a callee, of sorts, via `syscall`),
  `ft_strdup` calls `malloc`, and your C `main` calls into all your functions.
  Every one of those boundaries is a place where violating the convention causes
  a bug that surfaces somewhere other than where the mistake was made.
- **A concrete alignment trap**: suppose your function is entered normally (so
  `rsp % 16 == 8`, per the note above), and you push two registers to save them
  (16 bytes, keeping `rsp % 16 == 8`), then you need to call `malloc`. At this
  point `rsp % 16 == 8`, but `call` requires `rsp % 16 == 0` *before* it
  executes (so that after the return-address push, the callee sees the expected
  `%16 == 8`). You'd need one more 8-byte adjustment (an extra push, or `sub
  rsp, 8`) immediately before the `call` to fix this — and you'd need to undo it
  afterward. This kind of bookkeeping is exactly why people draw out stack
  diagrams on paper before writing the actual instructions.
- **Caller-saved vs callee-saved is a trust boundary, not a suggestion.** If you
  write a loop that keeps its counter in, say, `rcx`, and inside that loop you
  `call` some other function, you cannot assume `rcx` still holds your counter
  afterward — it's caller-saved, meaning the callee was free to clobber it. Any
  state you need to survive a `call` unscathed either needs to be in a
  callee-saved register, or saved to the stack yourself before the call and
  restored after.
- **This is also why `-no-pie` and absolute addressing matter for correctness,
  not just for the subject's rules** — but that connects more directly to
  Phase 12 (defense readiness), where it's covered in the context of why the
  subject forbids it.

## Checkpoint

**Q1: Using the office analogy and the real terms both: which register holds
the *third* integer argument to a function?**
<details><summary>Answer</summary>
`rdx` — the argument order is `rdi` (1st), `rsi` (2nd), `rdx` (3rd), `rcx` (4th),
`r8` (5th), `r9` (6th).
</details>

**Q2: You've written a loop that keeps a running count in `r12`, and partway
through each iteration you `call` a helper function. Do you need to worry about
`r12` being clobbered by that call? Why or why not?**
<details><summary>Answer</summary>
No — `r12` is callee-saved, so any correctly-written function you call is
obligated to preserve its value across the call (saving and restoring it
internally if it needs to use `r12` itself). If you'd used a caller-saved
register like `r10` instead, you would need to worry, and would have to save it
yourself.
</details>

**Q3: Right after your function is entered (i.e. right after the `call` that
invoked it executes), what is `rsp % 16`, and why isn't it 0?**
<details><summary>Answer</summary>
It's 8. The convention requires `rsp % 16 == 0` immediately *before* the `call`
instruction executes; `call` then pushes an 8-byte return address, which shifts
`rsp` down by 8, landing on `% 16 == 8` from the callee's perspective at entry.
</details>

**Q4: You need to `call malloc` from partway through your function, after
already pushing one register (8 bytes) to save it. Assuming you started at the
normal entry alignment, is `rsp` currently aligned correctly for the `call`? If
not, what's the minimal fix?**
<details><summary>Answer</summary>
At entry, `rsp % 16 == 8`. After pushing one 8-byte register, `rsp % 16 == 0` —
so in this specific case it actually *is* correctly aligned for the call. This
question is really testing whether you track the running total rather than
assume — if you'd pushed two registers (16 bytes) instead, you'd be back to
`rsp % 16 == 8`, misaligned, and would need one more 8-byte adjustment before
the call.
</details>

**Q5: What's the practical difference between a caller-saved and a callee-saved
register, stated as a rule you could apply while writing code?**
<details><summary>Answer</summary>
If a register is caller-saved, assume any `call` you make destroys its value —
save it yourself first if you need it afterward. If a register is callee-saved,
you as the *callee* are the one responsible for preserving its incoming value
(if you use it) and restoring it before you return — the caller can trust it
unconditionally.
</details>
