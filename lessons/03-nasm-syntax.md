# Phase 3 — NASM Syntax and Core Instructions

## Plain-English first

Think of an index card (an instruction) as a very short sentence with a verb
first: "move," "add," "compare," "jump." NASM is just one particular dialect for
writing these sentences down — a specific spelling and word-order convention.
There's a rival dialect (AT&T syntax, which is what you'd see if you asked GCC to
show you assembly) that writes the same sentences in a different word order and
with different punctuation. The instructions themselves — what the CPU actually
does — are identical either way. You're required to use the NASM/Intel dialect
for this project, so it's worth not accidentally learning AT&T habits from
random tutorials online.

A file full of these instruction-sentences needs to be organized a bit, the same
way a document has different sections (a cover page, a table of contents, the
body). Assembly files are split into a few labeled regions: one for the actual
instructions, one for fixed data values that already have a known starting
value, and one for data that just needs space reserved but starts as zero.

And just like a document might say "see page 12" or "as defined in the appendix,"
your instructions need a way to reference labels — including labels defined in
a completely different file, like a name you're borrowing from a chapter someone
else wrote (a libc function), or a label you're deliberately making visible so
someone else's file (like your C `main`) can reference yours.

## Now with the real terms

- **NASM** is the assembler tool. **Intel syntax** is the instruction-writing
  convention it uses by default (as opposed to AT&T syntax, used by GNU
  `as`/GCC's `-S` output). The core difference that matters immediately: Intel
  syntax writes `instruction destination, source` — read it right-to-left in
  terms of data flow ("take source, put it into destination").
- A `.s` (or `.asm`) file is divided into **sections**:
  - `.text` — where your actual instructions live.
  - `.data` — global data that has a known, non-zero initial value (e.g. a fixed
    string you want to print).
  - `.bss` — global data that just needs space reserved, initialized to zero,
    with no meaningful starting content to store in the file itself.
  For this project you'll spend nearly all your time in `.text`.
- `global <name>` marks a label as visible outside this file — this is how your
  C `main` (or the linker generally) can find and call, say, your `ft_strlen`
  label.
- `extern <name>` declares that a label is defined somewhere else, and you
  intend to reference/call it from this file — this is how you tell the
  assembler "trust me, `malloc` exists, I'll be calling it, go find its actual
  address at link time."

### The core instruction vocabulary

- `mov dest, src` — copy a value from `src` into `dest`. Doesn't touch flags.
  This is the single most-used instruction in any assembly program.
- `lea dest, [expr]` — "load effective address." Computes an address from the
  expression in brackets *without* reading the memory at that address, and puts
  the computed address itself into `dest`. Frequently used for fast arithmetic
  too (e.g. computing `a + b*4` in one instruction), since the bracket
  expression supports that kind of addressing math.
- `add dest, src` / `sub dest, src` — arithmetic, sets flags based on the
  result.
- `cmp a, b` — computes `a - b` internally, sets flags, discards the numeric
  result. Used purely to set up a subsequent conditional jump.
- `test a, b` — computes `a AND b` (bitwise), sets flags, discards the result.
  A common idiom is `test rax, rax` to cheaply check "is `rax` zero?" — the flag
  outcome is identical to `cmp rax, 0` in that specific case, but the encoding is
  typically smaller/faster.
- **Conditional jumps** — `je`/`jz` (jump if equal / if zero flag set),
  `jne`/`jnz`, `jl` (jump if less, *signed*), `jg` (jump if greater, *signed*),
  `jle`, `jge`. There's a parallel family for *unsigned* comparisons — `jb`
  (below), `ja` (above), `jbe`, `jae` — which read different flag combinations.
  Using the signed family when your values are logically unsigned (or vice
  versa) is a real, easy-to-make bug: it'll behave correctly for small/typical
  values and misbehave specifically at the boundary where sign interpretation
  diverges from unsigned interpretation.
- `jmp label` — unconditional jump, no flag check at all.
- `push src` / `pop dest` — `push` decrements `rsp` by 8 and stores `src` at the
  new top; `pop` loads the value at the current top into `dest` and increments
  `rsp` by 8.
- `call label` — pushes the address of the instruction immediately after this
  `call` (the return address), then jumps to `label`.
- `ret` — pops a value off the stack and jumps to it. This only does the right
  thing if the value currently on top of the stack is genuinely the return
  address `call` pushed — if your function has mismatched pushes/pops before
  `ret`, you'll jump to garbage.

## Deep dive

- **Operand order is the single most common transcription mistake** when
  reading examples online, because so much material defaults to AT&T syntax
  (`instruction src, dest` — the *opposite* order, often with a `%` prefix on
  registers and `$` on immediates). If a snippet you're reading has `%rax` or
  `movl $5, %eax`-looking syntax, it's AT&T — mentally (or actually) flip the
  operand order before trusting it as a NASM example.
- **`lea` doesn't touch memory.** This surprises people: `lea rax, [rbx + 8]`
  does *not* read whatever is stored at address `rbx + 8` — it computes the
  number `rbx + 8` and puts that number into `rax`. Compare with `mov rax, [rbx
  + 8]`, which *does* read memory at that address. The brackets mean "compute
  this address" for `lea`, but "read/write the memory at this address" for
  `mov`. Confusing these two is a very common source of "my pointer arithmetic
  is right but I'm getting garbage data" bugs.
- **Instruction size suffixes and operand size inference**: NASM generally
  infers the operation size from the registers involved (`mov eax, [rbx]` is a
  32-bit load because `eax` is 32-bit). When there's ambiguity (e.g. moving an
  immediate into a bare memory address with no register to infer size from),
  you'll need an explicit size directive like `byte`, `word`, `dword`, `qword`
  — you'll encounter this mostly when writing directly to memory rather than a
  register.
- **Signed vs unsigned jump families exist because the same bit pattern means
  different things depending on interpretation.** The byte `0xFF` is `255` if
  you read it as unsigned, or `-1` if you read it as signed (two's complement).
  `cmp` sets flags based on the raw bit-level subtraction either way — it's the
  *jump instruction* you choose afterward that decides whether those flags get
  interpreted as a signed or unsigned comparison. This is exactly why the two
  families exist and why picking the wrong one only breaks things at specific
  boundary values, not universally — which makes it a nasty bug to catch by
  accident.

## Checkpoint

**Q1: In `mov rax, [rbx + 8]`, what actually happens: is a number computed, or
is memory read?**
<details><summary>Answer</summary>
Memory is read. `mov` with a bracketed operand dereferences — it computes the
address `rbx + 8` and then loads the 8 bytes stored at that address into `rax`.
</details>

**Q2: In `lea rax, [rbx + 8]`, what actually happens?**
<details><summary>Answer</summary>
No memory access occurs. The address `rbx + 8` is computed as a plain number and
stored directly into `rax` — `lea` never dereferences its bracketed operand.
</details>

**Q3: You see an online example with `movl $5, %eax`. What syntax dialect is
that, and how would you rewrite it in NASM/Intel syntax?**
<details><summary>Answer</summary>
That's AT&T syntax. In Intel/NASM syntax it becomes `mov eax, 5` — operand order
flips (destination first), and the `$`/`%` sigils are dropped.
</details>

**Q4: What's the difference between what `cmp` does to its operands versus what
`sub` does, given identical operands?**
<details><summary>Answer</summary>
Both compute `a - b` and set the same flags. `sub` additionally overwrites the
destination operand with that result; `cmp` discards the result and leaves both
operands unmodified.
</details>

**Q5: You need to check whether an unsigned value in `rax` is greater than an
unsigned value in `rbx`. Which jump instruction family should you reach for, and
what would go wrong if you used the signed family instead?**
<details><summary>Answer</summary>
The unsigned family (`ja` for "above," i.e. unsigned greater-than). Using the
signed family (`jg`) would work correctly for values that fit comfortably as
positive signed numbers, but would misbehave for any value whose top bit is set
— such a value is a large positive number unsigned, but would be interpreted as
negative under the signed comparison, flipping the outcome.
</details>

**Q6: What does `call` push onto the stack before jumping, and what does `ret`
assume is on top of the stack when it runs?**
<details><summary>Answer</summary>
`call` pushes the address of the instruction immediately following it (the
return address). `ret` assumes that same return address is currently on top of
the stack, pops it, and jumps there — if the stack's top doesn't actually hold
that address (due to mismatched pushes/pops earlier in the function), `ret` will
jump to whatever garbage value happens to be there instead.
</details>
