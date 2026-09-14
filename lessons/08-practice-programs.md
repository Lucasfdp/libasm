# Phase 8 — Tiny Throwaway Programs First

## Plain-English first

You wouldn't learn to drive by getting on a highway during rush hour. You'd
first practice in an empty parking lot: start the car, stop the car, turn left,
turn right — each skill in isolation, with nothing else demanding your
attention, so that when you combine them later in real traffic, each individual
motion is already automatic and you can focus on the combination instead of
relearning the basics under pressure.

This phase is the empty parking lot. Before touching any of the six required
`ft_` functions — where you'll simultaneously need correct loops, correct
memory access, correct syscalls, correct error handling, and correct calling
convention all at once — you practice each foundational motion completely on
its own, in a program with no other complexity around it.

## Now with the real terms

Three small standalone programs, each isolating a specific skill:

1. **Exit with a specific status code.** A program whose entire job is to call
   the `exit` syscall with a chosen number, so you can confirm from the shell
   (checking the exit code after running it) that the number you chose is
   exactly what came back. This exercises: the basic file structure (sections),
   the freestanding entry point (`_start` rather than `main` — a program with no
   C runtime underneath it has no `main`-calling machinery, so the actual
   OS-level entry point must be defined directly), loading a syscall number into
   `rax`, loading an argument, and executing `syscall`.

2. **Write a fixed string to stdout, then exit.** This adds the `.data` section
   (to hold the string's bytes, since it has a real, known, non-zero initial
   value) and multi-argument syscalls — `write` needs a file descriptor, a
   buffer address, and a length, all three placed in the correct registers per
   Phase 5.

3. **A simple counting loop.** Using `cmp` plus a conditional jump back to an
   earlier label, count from one number up to another. This is deliberately the
   same loop *shape* you'll need for `ft_strlen` shortly after, but with no
   string-scanning logic layered on top — just the raw mechanics of "loop until
   a condition is met."

Alongside writing these, **practice stepping through each one instruction by
instruction in a debugger** (gdb or lldb), watching register values change live
after each step, rather than only ever running the program start-to-finish and
checking the final output.

## Deep dive

- **Why `_start` and not `main`?** In a normal C program, `main` isn't actually
  the true entry point — the C runtime (startup code sometimes referred to as
  `crt0`, linked in automatically when you compile with `gcc`) runs first,
  performs setup (initializing the C library, setting up argc/argv, etc.), and
  *then* calls `main` on your behalf. A fully freestanding assembly program with
  no C runtime involved has no such setup code calling anything for it — the OS
  itself jumps directly to whatever symbol is marked as the actual entry point,
  which by default is named `_start`. (Once you get to the actual project, your
  `ft_` functions will typically be linked *with* a C `main` and the normal C
  runtime, so you won't need `_start` there — this distinction matters
  specifically for these isolated practice programs.)
- **Why does the string go in `.data` and not `.bss`?** `.bss` reserves space
  without storing any actual content in the file — it's zero-filled by the
  loader at program start. A string literal has specific, non-zero byte content
  that must be part of the binary itself, so it belongs in `.data`, which does
  store real initial content in the file.
  as `.bss` would only give you zeroed-out space, not your actual message.
- **Debugging by single-stepping is a skill, not just a tool.** The value isn't
  "having a debugger open" — it's building the habit of predicting what a
  register or flag *should* be after the next instruction, stepping once, and
  checking whether reality matched your prediction. Doing this deliberately on
  simple programs, where you can hold the entire expected state in your head,
  builds the calibration you'll need once you're debugging something with real
  calling-convention or alignment bugs, where guessing without checking wastes
  far more time than the careful version would have.
- **These programs are genuinely disposable.** Don't try to make them
  reusable, general, or polished — the entire point is fast, low-stakes
  repetition of one mechanic at a time. Write one, run it, break it on purpose
  and see what changes, then move to the next.

## Checkpoint

**Q1: Why can't a fully freestanding assembly program (no C runtime linked in)
use `main` as its entry point the way a C program does?**
<details><summary>Answer</summary>
Because `main` is only ever invoked by C runtime startup code, which itself has
to be called by something — in a normal C program that's arranged automatically
by the compiler/linker's default startup files. A freestanding program has none
of that machinery, so the actual OS-level entry point must be defined directly,
which by convention is a symbol named `_start`.
</details>

**Q2: If you tried to store a string literal's bytes in `.bss` instead of
`.data`, what would actually happen when the program ran?**
<details><summary>Answer</summary>
`.bss` doesn't store real content in the binary at all — it's just reserved
space that gets zero-filled at load time. So you wouldn't get your string's
actual bytes; you'd get a block of zero bytes of the right size instead.
</details>

**Q3: For the "write a fixed string" practice program, name the three pieces of
information the `write` syscall needs, and roughly where in the registers each
one goes.**
<details><summary>Answer</summary>
A file descriptor (in `rdi`), a pointer to the buffer/string (in `rsi`), and
the length in bytes to write (in `rdx`) — with the syscall number for `write`
itself in `rax` before executing `syscall`.
</details>

**Q4: What's the actual point of single-stepping through these tiny programs in
a debugger, beyond "checking that they work"?**
<details><summary>Answer</summary>
It builds the habit of predicting expected register/flag state before each
instruction and verifying it directly, rather than only checking final output —
a calibration skill that becomes essential once debugging more complex,
harder-to-predict bugs (calling-convention violations, alignment issues) later
in the project.
</details>
