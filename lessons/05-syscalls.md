# Phase 5 — Linux Syscalls on x86-64

## Plain-English first

Everything so far has been about your program talking to itself — one of your
functions calling another. But some things a program wants to do — write text to
the screen, read from a file, exit the process — aren't things the program is
actually allowed to do on its own. The operating system's kernel is the only
thing with permission to touch the actual hardware (the screen, the disk, other
processes). Your program has to *ask* the kernel to do these things on its
behalf.

Think of it like a hotel where guests (your program) aren't allowed to unlock
doors or send outside mail themselves — they have to go through the front desk
(the kernel). There's a specific, standardized request form for each kind of
service: form #1 is "please write these bytes to this destination," form #0 is
"please read bytes from this source into my hands," and so on, each with a fixed
form number the front desk recognizes instantly. You fill in the form number and
the request details, ring the special service bell (a specific CPU instruction
dedicated exactly to this), and the front desk (the kernel) takes over
momentarily, does the actual privileged work, and hands control back to you with
a result.

Critically, this is a *different* front desk from the ordinary "calling a
coworker's function" process from Phase 4 — it has its own, very similar but
not identical, set of rules for which trays hold which piece of the request, and
its own convention for reporting back if something went wrong.

## Now with the real terms

- The **`syscall`** instruction is the "service bell" — a dedicated CPU
  instruction that transitions execution into the kernel to perform a privileged
  operation, then returns control to your program afterward.
- **Which operation runs** is selected by a **syscall number** you place in
  `rax` before executing `syscall`. On x86-64 Linux, `read` is syscall number
  `0` and `write` is syscall number `1`. (These numbers are specific to this
  architecture and OS — they are not portable across platforms, and you should
  confirm them against the current syscall table rather than trusting memory
  alone.)
- **Argument registers for a syscall**: `rdi, rsi, rdx, r10, r8, r9` — almost
  the same as the normal calling convention from Phase 4, with one important
  difference: the **4th argument goes in `r10`, not `rcx`**. This is because the
  `syscall` instruction itself uses `rcx` and `r11` internally (to save the
  return address and flags, respectively) as part of how the CPU transitions
  into and out of kernel mode — so `rcx` isn't available to carry a 4th argument
  the way it would be for an ordinary function call.
- **Return value**: comes back in `rax`, same as an ordinary call. But the
  *meaning* of that value differs on error: a raw syscall signals failure by
  returning a small **negative** number, whose absolute value is the error code
  (e.g. `-9` means "error code 9," which is `EBADF`, bad file descriptor). This
  is different from how a C library wrapper function reports errors (see below).
- A **raw syscall** is exactly what's described above — direct communication
  with the kernel, no library involved. A **libc wrapper** (like the ordinary C
  `write()` function you'd normally call) is a small function that sets up the
  syscall, invokes it, and then *translates* the kernel's raw negative-error
  convention into the convention C programmers expect: return `-1` on error, and
  separately set the global `errno` variable to the positive error code. Because
  the subject requires you to reimplement `write`/`read` from scratch in
  assembly using raw syscalls, you are responsible for doing this translation
  step yourself — the kernel will not do it for you.

## Deep dive

- **Why does the kernel even need a special instruction instead of a normal
  `call`?** Ordinary function calls stay within your program's privilege level.
  The kernel runs at a higher privilege level specifically so that ordinary
  programs *can't* just directly manipulate hardware or other processes'
  memory — `syscall` is a controlled, narrow doorway between the two privilege
  levels, and the kernel decides exactly what happens once you ring that bell,
  rather than you jumping directly into arbitrary kernel code.
- **The negative-return convention is compact but easy to mishandle.** A
  successful `write` returns the number of bytes actually written (which could
  legitimately be `0` in some edge cases, and is always non-negative). A failed
  `write` returns a small negative number. So the check is simple — "is `rax`
  negative?" — but it's easy to forget that you must then negate it before
  treating it as an errno value, and separately return `-1` (not the raw
  negative kernel value) to whatever called your `ft_write`, since that's the
  convention *your* function's caller expects, matching what real `write()`
  does.
- **Partial writes/reads are a real possibility, not just a theoretical edge
  case.** A successful `write` syscall is allowed to write *fewer* bytes than
  you asked for (especially for large sizes, or to certain kinds of file
  descriptors), and this is not an error — it's a valid, non-negative return
  value smaller than your requested length. The man pages for `write`/`read`
  describe this, and it's worth deciding deliberately whether your
  implementation needs to loop to guarantee a full write, or whether returning
  the syscall's result directly (matching the true underlying libc semantics)
  is the correct choice for the subject's requirements.
- **The syscall argument-register list existing separately from the normal ABI
  is a frequent point of confusion.** It's extremely easy to instinctively put a
  4th argument in `rcx` out of habit from Phase 4's ordinary calling convention,
  and this bug won't even necessarily crash — it'll just silently pass garbage
  as the 4th syscall argument, which can be very confusing to debug since the
  syscall might still "work" incorrectly rather than failing outright.

## Checkpoint

**Q1: Using the hotel analogy: what's the "service bell," and what's the "form
number" in real terms?**
<details><summary>Answer</summary>
The service bell is the `syscall` instruction. The form number is the syscall
number, placed in `rax` before executing `syscall` (e.g. `0` for `read`, `1`
for `write` on x86-64 Linux).
</details>

**Q2: Which register carries the 4th syscall argument, and why isn't it the
same register used for the 4th argument in an ordinary function call?**
<details><summary>Answer</summary>
`r10`. It differs from the ordinary calling convention's `rcx` because the
`syscall` instruction itself uses `rcx` (and `r11`) internally to manage the
transition into and out of kernel mode, so `rcx` isn't free to carry a user
argument in this context.
</details>

**Q3: A `write` syscall fails due to a bad file descriptor and returns `-9` in
`rax`. Walk through, step by step, what your `ft_write` needs to do with that
value before returning to its own caller.**
<details><summary>Answer</summary>
Detect that `rax` is negative. Negate it to get the positive errno code (`9`,
i.e. `EBADF`). Store `9` into the thread's errno location (Phase 6 covers how).
Return `-1` from `ft_write` itself — not `-9` — since `-1` plus a set `errno` is
the convention the function's own caller (following normal C library
conventions) expects.
</details>

**Q4: Is it possible for `write` to succeed but write fewer bytes than
requested? What does that mean for how you interpret a non-negative return
value?**
<details><summary>Answer</summary>
Yes — a partial write is a valid, non-error outcome, and the return value in
that case is simply the (smaller) number of bytes actually written, not an
error signal. A non-negative return value should be treated as "this many bytes
were processed," not necessarily "all requested bytes were processed."
</details>

**Q5: Why might accidentally putting a syscall's 4th argument in `rcx` instead
of `r10` fail to produce an obvious crash?**
<details><summary>Answer</summary>
Because `rcx` gets overwritten by the `syscall` instruction itself as part of
the kernel transition, the kernel simply reads whatever garbage happens to be in
`r10` as the intended 4th argument instead of your actual value — the syscall
still executes, just with a wrong argument, which can produce subtly incorrect
behavior rather than an outright crash, making it harder to notice and debug.
</details>
