# Phase 12 — Defense Readiness

## Plain-English first

Everything in this phase is old material — there's nothing new to learn here.
The entire point of Phase 12 is being able to explain what you already know
out loud, from memory, to another person who's going to ask "why," not just
"what," and who might push back or ask you to prove it live. Knowing something
well enough to answer a checkpoint question with the file open next to you is a
different skill from explaining it cold, under mild pressure, to a peer who's
actively trying to find gaps.

A useful test: could you explain each item below to a friend who has never
touched assembly, in a couple of sentences, without notes, and have them come
away actually understanding it — not just hearing technically correct words
strung together?

## Now with the real terms, and how to actually explain each one

### Why is `-no-pie` forbidden?
**PIE** (position-independent executable) means the binary's code can be loaded
at a different, randomized memory address every time it runs. This is a real
security measure — **ASLR** (address space layout randomization) — that makes
certain classes of exploit meaningfully harder, because an attacker can't
reliably predict where a piece of code or data will sit in memory ahead of
time. `-no-pie` disables this, forcing the binary to always load at a fixed,
predictable address — which the subject forbids specifically to keep the
project's binaries built the security-conscious way by default. Practically,
this constrains how you can write assembly: you generally can't assume a fixed
absolute address for things like string literals, and instead lean on
RIP-relative addressing (addressing memory relative to the current instruction
pointer, which NASM and the linker handle for you when your code is written in
a position-independent-friendly way).

### Why does the calling convention matter?
It's the *only* reason code written by different people — you, the authors of
libc, the C compiler that built your `main` — can call each other's functions
correctly without needing to inspect each other's source first. It's a shared
contract about where arguments go, where the return value goes, which
registers are safe to clobber versus must be preserved, and how the stack must
be aligned. Violate it, and the failure typically doesn't show up at the site
of your mistake — it shows up somewhere downstream, inside a function you
didn't even write, which is exactly the kind of bug that's painful (and
embarrassing) to debug live in front of an evaluator.

### How does errno get set, end to end?
Walk the full chain out loud: a syscall returns a negative value on failure →
you negate it to recover the positive error code → you call
`__errno_location` (or `__error` on macOS), respecting the calling convention
including stack alignment, to obtain a pointer to the current thread's errno
storage → you write the error code through that pointer → your function
returns `-1` to signal failure to whatever called it, matching the convention
real C library functions use.

### What happens on syscall failure?
The kernel returns a small negative number instead of a byte count or success
indicator. That raw kernel convention isn't what a C caller expects — it must
be translated (negate it, set errno, return `-1`) rather than passed straight
through, because your `ft_write`/`ft_read` are expected to behave like their
real libc counterparts to whatever calls them, not like a raw, untranslated
syscall.

## Deep dive — likely follow-up questions and how to hold your ground

- **"What if I called a syscall directly without going through libc's wrapper —
  why does that even matter here?"** Because the subject explicitly requires
  raw syscalls for `ft_write`/`ft_read` (not calling the real libc `write`),
  which is precisely why you're responsible for the negative-to-errno
  translation yourself — the kernel doesn't do it, and there's no libc wrapper
  doing it either in your implementation.
- **"Show me where in your code the stack stays aligned before you call
  `malloc`."** Be ready to point to the actual instructions and count bytes —
  every `push`, every `sub rsp, N` — from function entry to the `call`, and
  state what `rsp % 16` is at each step. This is the kind of thing worth
  rehearsing on your actual code before the defense, not just understanding in
  the abstract.
- **"What would happen if you removed your error check after the syscall?"** A
  good, concrete answer: the function would return whatever raw value the
  kernel gave back (including negative values on failure) directly to the
  caller, which no longer matches the `-1`-plus-errno convention real callers
  expect, and errno would never get set on failure at all — silently wrong
  behavior rather than a crash, which is arguably worse.
- **"Why didn't you just use `-1` as a fixed constant everywhere errno should
  be set to something specific?"** Because different failures have different
  meaningful error codes (e.g. `EBADF` for a bad file descriptor vs. other
  codes for other failure reasons) — the actual value comes from negating
  whatever the kernel returned, not from a single hardcoded constant, so that
  callers checking errno afterward get an accurate, specific reason.

## Checkpoint

**Q1: Explain, in one or two sentences and without technical shorthand, why
`-no-pie` is forbidden.**
<details><summary>Answer</summary>
It's a security measure: PIE lets the OS load your program at a randomized
memory address each run (ASLR), making certain exploits harder by removing
predictable addresses an attacker could rely on. `-no-pie` would disable that
protection, which is why the subject forbids it.
</details>

**Q2: Give the shortest correct explanation you can for "why does stack
alignment matter before a `call`."**
<details><summary>Answer</summary>
Some functions (including parts of libc) use SSE instructions that require the
stack to be 16-byte aligned at that point — if it isn't, those instructions
fault, and the resulting crash appears inside the called function rather than
at the actual site of the misalignment mistake.
</details>

**Q3: Walk through, from memory and out loud, the complete path a failed
`ft_write` call takes from the syscall returning to the function's own return
value.**
<details><summary>Answer</summary>
`syscall` executes and returns a negative value in `rax`. You detect it's
negative and negate it to get the positive errno code. You call
`__errno_location` (respecting calling convention and stack alignment) to get a
pointer to the thread's errno storage, and write the code through that
pointer. You set `rax` to `-1` and return that to the caller.
</details>

**Q4: An evaluator asks you to remove your post-syscall error check and predict
what changes. What's your answer?**
<details><summary>Answer</summary>
The function would pass the kernel's raw return value straight through to the
caller, including negative values on failure, rather than the expected `-1`;
and errno would never get set on a failure, since that logic lives entirely in
the error-check branch you just removed — the function would appear to "work"
in the sense of not crashing, while actually behaving incorrectly on every
failure case.
</details>

**Q5: Why can't you just hardcode a single fixed errno value for every possible
syscall failure?**
<details><summary>Answer</summary>
Because different failures correspond to different, specific error codes
(e.g. a bad file descriptor versus other failure reasons), and the correct
value comes directly from negating whatever the kernel actually returned for
that specific failure — hardcoding one value would give callers an inaccurate,
misleading reason for the failure.
</details>

---

You've now covered every phase. Go back through the checkpoints in
`09-mandatory-functions.md` through `11-bonus.md` one more time with your
actual written code open next to you, and confirm each answer still holds true
against what you actually implemented — not just against the general
principle.
