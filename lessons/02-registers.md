# Phase 2 — The x86-64 Register Set

## Plain-English first

Go back to the desk with its small number of trays. Here's a detail we skipped:
each tray is actually large enough to hold a big number — a 64-bit number, so
something up to about 18 quintillion. But sometimes you only care about a small
part of what's in the tray — say, just enough to hold a number up to 4 billion,
or up to 65,535, or up to 255. Rather than needing a separate small tray for
that, each tray has "viewing windows" — you can look at (or write into) just the
bottom chunk of the same tray, in four different sizes, and it's still physically
the same tray.

There are only around 16 of these trays total, and they mostly don't have
job titles — any of them can hold any number, for almost any purpose. But two of
them *do* have a standing job by convention: one always points at "the current
top of the scratch-space stack of trays" from Phase 1, and another is
conventionally used as a stable reference point while the worker is in the
middle of following a sub-sequence of cards (a function), so they don't lose
track of where things are even as the scratch stack shifts around underneath
them.

Finally, there's a small panel of indicator lights next to the desk. After
certain operations — subtracting two numbers, for instance — one or more lights
automatically switch on or off based on the result: one light for "the result
was exactly zero," one for "the result was negative," and a couple of others for
more specific overflow situations. The worker doesn't have to remember the
result of the last subtraction — they can just glance at the lights. Some
instruction cards say "only jump to card #47 if the zero light is on right now."

## Now with the real terms

- The 16 "trays" are the **general-purpose registers**: `rax, rbx, rcx, rdx, rsi,
  rdi, rbp, rsp, r8, r9, r10, r11, r12, r13, r14, r15`. On x86-64 each is 64 bits
  wide.
- The "viewing windows" are the **sub-register views**. Taking `rax` as the
  example: `rax` is the full 64 bits, `eax` is the low 32 bits of that same
  physical register, `ax` is the low 16 bits, and `al` is the low 8 bits. (There's
  also `ah`, the second-lowest byte, on some of the older registers — you won't
  need it here.) The same pattern of names applies to `rbx/ebx/bx/bl`,
  `rcx/ecx/cx/cl`, `rdx/edx/dx/dl`, and so on.
- **Important gotcha**: writing to the 32-bit view (`eax`) automatically zeroes
  the *entire upper 32 bits* of the 64-bit register. Writing to the 16-bit or
  8-bit views does *not* do this — it leaves the untouched upper bits exactly as
  they were. This inconsistency has bitten a lot of people; if you `mov eax, 0`
  you can trust `rax` is now fully zero, but if you `mov al, 0` the rest of `rax`
  is whatever it happened to be before.
- `rsp` (**stack pointer**) is the register with the standing job of always
  pointing at the current top of the stack. Don't repurpose it for scratch
  arithmetic — the CPU (and every function you call) trusts it to mean exactly
  one thing.
- `rbp` (**base pointer**, sometimes called the frame pointer) is conventionally
  set once near the start of a function and left alone for the rest of that
  function's body, giving you a fixed reference point to locate local variables
  or saved values on the stack, even as `rsp` itself moves around during the
  function (e.g. from further pushes).
- The "indicator lights" are the **flags register**, `rflags`, specifically a
  handful of individual bits within it:
  - **ZF (zero flag)** — set when the result of the last arithmetic/logical
    instruction was exactly zero.
  - **SF (sign flag)** — set when the result was negative (its most significant
    bit is 1).
  - **CF (carry flag)** — set on unsigned overflow or borrow.
  - **OF (overflow flag)** — set on *signed* overflow.
- **Conditional jump instructions** (`je`, `jne`, `jl`, `jg`, ...) don't
  recompute anything — they simply check the current state of these flag bits,
  which were set by whatever `cmp`, `test`, `add`, `sub`, etc. ran most recently.

## Deep dive

- Registers `r8`–`r15` are a 64-bit-only extension (the original 32-bit x86 only
  had 8 general-purpose registers). Their sub-register names follow a numeric
  pattern instead of letters: `r8` (64-bit) → `r8d` (32-bit) → `r8w` (16-bit) →
  `r8b` (8-bit).
- Even though most registers are "general purpose," in practice several have
  strong conventional roles that you should treat as fixed for this project:
  `rsp` for the stack pointer, `rbp` for the frame pointer, `rax` for return
  values (Phase 4), and `rdi`/`rsi`/`rdx`/`rcx`/`r8`/`r9` for the first six
  function arguments (Phase 4). Using them "generally" against these conventions
  will break interoperability with C code and libc.
- The flags register is itself a normal-sized register under the hood, but you
  essentially never read or write it wholesale in this project — you interact
  with it exclusively through instructions that implicitly set specific bits
  (`cmp`, `test`, arithmetic instructions) and instructions that implicitly read
  specific bits (conditional jumps, `setcc` family, though you likely won't need
  `setcc` here).
- A subtlety worth internalizing early: `cmp a, b` sets flags as if it computed
  `a - b`, but discards the numeric result — only the flags persist. So `cmp rax,
  rbx` followed by `jl label` reads as "subtract `rbx` from `rax`, don't keep the
  result, but jump to `label` if that hypothetical subtraction would have been
  negative (signed)." This flags-based indirection is why instruction order
  matters: any instruction between your `cmp` and your conditional jump that
  *also* touches flags will silently invalidate the comparison you thought you
  were checking.

## Checkpoint

**Q1: `rbx` currently holds `0x123456789ABCDEF0`. You execute `mov ebx, 0`. What
does `rbx` hold afterward, and why?**
<details><summary>Answer</summary>
`0x0000000000000000`. Writing to the 32-bit view (`ebx`) zero-extends and clears
the entire upper 32 bits of the full 64-bit register — this is a defined
behavior of the architecture, not a bug.
</details>

**Q2: Same starting value, but this time you execute `mov bl, 0`. What does
`rbx` hold afterward?**
<details><summary>Answer</summary>
`0x123456789ABCDE00` — only the lowest byte changes. Unlike the 32-bit write,
writing to the 8-bit (or 16-bit) view leaves the rest of the register untouched.
</details>

**Q3: What is `rbp` conventionally used for, and why is it useful that it stays
fixed for the duration of a function body even as `rsp` moves?**
<details><summary>Answer</summary>
It's used as a stable reference point (frame pointer) for locating local
variables/saved values on the stack. Because `rsp` can shift as you push/pop
things during the function, having a fixed reference makes it easier to reliably
find a given stack slot by a constant offset from `rbp`, rather than tracking a
constantly moving offset from `rsp`.
</details>

**Q4: What does `cmp rax, rbx` actually compute, and what happens to that
result?**
<details><summary>Answer</summary>
It computes `rax - rbx` internally, sets the flags register based on that result
(zero flag, sign flag, carry flag, overflow flag as appropriate), and then
discards the numeric result entirely — neither `rax` nor `rbx` is modified.
</details>

**Q5: Why can inserting an unrelated arithmetic instruction between a `cmp` and
its intended conditional jump be a bug?**
<details><summary>Answer</summary>
Because that unrelated instruction may also set flags (most arithmetic/logical
instructions do), overwriting the flag state the `cmp` set — so the conditional
jump ends up reacting to the wrong comparison entirely.
</details>
