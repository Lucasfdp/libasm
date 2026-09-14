# Phase 9 — Mandatory Functions, Easiest to Hardest

## Plain-English first

Six functions are required. They're not equally hard, and — usefully — they
build on each other almost perfectly if you tackle them in the right order,
each one adding exactly one new difficulty on top of skills the previous ones
already exercised. Think of it as a staircase: `ft_strlen` is the bottom step
(just look at things), `ft_strcmp` adds "look at two things side by side,"
`ft_strcpy` adds "and also write something down," `ft_write`/`ft_read` add
"and also ask the kernel for a favor and handle it saying no," and `ft_strdup`
combines nearly everything before it plus "and also ask a coworker (`malloc`)
for a favor and handle *them* saying no too."

## Now with the real terms, in order

### `ft_strlen` — the simplest possible function
One input (a pointer), one output (a count), no writes, no syscalls, no error
path at all. Just walk forward byte by byte from the given address until you
hit a zero byte, counting as you go, and return the count in `rax`. This is
purely about proving you can write a correct loop (Phase 3's `cmp` +
conditional jump pattern) and return a value through the calling convention
(Phase 4) — nothing else is layered on top yet.

### `ft_strcmp` — comparing two things in lockstep
Same scanning idea as `ft_strlen`, but now advancing through *two* pointers at
once and comparing the bytes at each position. The new wrinkle isn't the
looping mechanic — it's getting the *return value convention* exactly right:
`ft_strcmp` should return the numeric difference between the first pair of
differing bytes (not just `-1`/`0`/`1`), and needs to correctly stop at
whichever string's terminator comes first.

### `ft_strcpy` — reading and writing together
Adds the one new mechanic `ft_strlen`/`ft_strcmp` didn't need: writing to
memory, not just reading it. You're copying source bytes into a destination
buffer one at a time, including the terminating zero byte, and the function
must return the destination pointer (per the real `strcpy` man page contract)
— a detail that's easy to forget since it means preserving the original
destination address in a register throughout the copy loop, separate from
whatever register you use to walk forward through the buffer.

### `ft_write` and `ft_read` — your first real syscalls
This is where Phase 5 (syscalls) and Phase 6 (errno) combine directly: issue
the appropriate `syscall`, check whether the result is negative, and if so,
translate that into a proper errno write plus a `-1` return, exactly as
described in those phases. There's no new "logic" difficulty here compared to
the phases you've already worked through — the difficulty is entirely about
executing that translation correctly and consistently, under the added
constraint of the calling convention now genuinely mattering (since you're
calling `__errno_location` from inside these).

### `ft_strdup` — combining everything, plus calling out to `malloc`
Conceptually: measure the source string's length (strlen logic), ask `malloc`
for that many bytes plus one (for the terminator), then copy the source into
the new buffer (strcpy logic). The genuinely new piece is that the destination
buffer isn't handed to you as an argument — you must obtain it yourself by
correctly calling an external C function (`malloc`), which means this is your
first real end-to-end test of Phase 4's calling convention with an external,
non-syscall function: correct argument placement, correct stack alignment at
the `call`, and correctly using whatever comes back in `rax`. You also must
handle `malloc` returning `NULL` (allocation failure) rather than assuming it
always succeeds — dereferencing a `NULL` pointer to start copying into it would
crash.

### The required C `main`
The subject requires a `main` function, compiled together with your library,
that demonstrates the library actually works. This doesn't need to be
exhaustive testing (that's Phase 10's job) — it needs to be enough to
convincingly show each function is called and behaves correctly, since this is
literally the artifact that proves, to a grader or to you, that linking and
calling your assembly from C actually functions end to end.

## Deep dive

- **Order matters for a real pedagogical reason, not just convenience.** If you
  attempt `ft_strdup` first, you're trying to debug loop logic, memory writes,
  *and* external-call calling-convention issues simultaneously, with no way to
  isolate which one is actually broken when something goes wrong. Working
  bottom-up means that by the time you hit a bug in `ft_strdup`, you already
  trust your loop and memory-write logic completely (because `ft_strlen` and
  `ft_strcpy` already proved those work), so you know with much more confidence
  that any remaining bug is specifically in the new part — the `malloc` call.
- **`ft_strcmp`'s return value is a common source of subtly wrong
  implementations.** Returning `1`/`-1`/`0` instead of the actual byte
  difference will often *pass* casual testing (since many callers just check
  sign), but it isn't what the real `strcmp` contract specifies, and the
  subject explicitly asks you to match real function behavior via the man
  pages — worth checking this specifically rather than assuming "close enough"
  is correct.
- **Don't forget non-happy-path behavior the man pages specify**, even where
  the subject doesn't spell it out explicitly: what should `ft_strcpy` do with
  overlapping buffers (real `strcpy` has undefined behavior there — you don't
  need to handle it specially, but it's worth knowing this rather than being
  surprised), what happens with zero-length input, etc. Reading the actual man
  pages referenced in the subject (`man 3 strlen`, `man 3 strcpy`, and so on)
  before implementing each function is genuinely part of the assignment, not
  optional background reading.
- **`ft_write`/`ft_read` are good places to double check your syscall argument
  register usage against Phase 5 one more time**, specifically the `r10`
  detail for any 4-argument syscalls you might touch elsewhere later — `write`
  and `read` only need 3 arguments each, so this particular gotcha won't bite
  you here, but it's worth re-confirming you understand *why* it wouldn't
  apply to these two specifically (they don't have a 4th argument at all).

## Checkpoint

**Q1: Why is starting with `ft_strlen` specifically a good idea, in terms of
what it does and doesn't force you to get right simultaneously?**
<details><summary>Answer</summary>
It only reads memory (no writes), makes no syscalls or external calls, and has
no error path — so it isolates "write a correct loop and return a value via the
calling convention" as a single skill, without any other complexity to
confound debugging if something's wrong.
</details>

**Q2: What's the one genuinely new mechanic `ft_strcpy` requires that
`ft_strlen` and `ft_strcmp` don't?**
<details><summary>Answer</summary>
Writing to memory (the destination buffer) — the earlier two functions only
ever read memory.
</details>

**Q3: `ft_strcmp` should return what, precisely, when the two strings differ —
and what's the subtly wrong version people commonly write instead?**
<details><summary>Answer</summary>
It should return the numeric difference between the first differing pair of
bytes (matching real `strcmp`'s contract), not merely a flattened `-1`/`0`/`1`
— the flattened version is a common shortcut that often passes casual testing
but doesn't match the actual specified behavior.
</details>

**Q4: Name the two things `ft_strdup` needs that no earlier function in this
list did.**
<details><summary>Answer</summary>
A correctly executed call to an external function it doesn't control
(`malloc`), following the full calling convention including stack alignment;
and explicit handling of that call potentially failing (`malloc` returning
`NULL`), which must be checked before being used, rather than assumed to always
succeed.
</details>

**Q5: Why is working through functions in this specific order more useful for
debugging than attempting them in an arbitrary order?**
<details><summary>Answer</summary>
Each function isolates and proves exactly one new mechanic. By the time you
reach a harder function, you already trust the mechanics proven by the earlier
ones, so when something breaks you can localize the bug to the newest piece
instead of having multiple unproven mechanics tangled together with no way to
tell which one is actually at fault.
</details>
