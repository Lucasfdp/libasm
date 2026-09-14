# Phase 1 — How a CPU Actually Executes Something

## Plain-English first

Imagine a worker standing at a desk. On the desk are a handful of small trays —
maybe 16 of them — each one able to hold exactly one number. Behind the worker is
a gigantic warehouse of numbered shelves, stretching further than they can see,
each shelf holding one number too.

The worker has a stack of index cards, each with one very simple instruction on
it, like "take the number from tray 3 and shelf #4021, add them, put the result in
tray 3" or "if tray 1 currently holds zero, skip ahead to card #47." The worker
reads one card, does exactly what it says, and moves to the next card. That's the
entire job. There's no understanding of what the numbers *mean* — no concept of
"this number is a price" or "this shelf holds a name." Numbers are just numbers.
Meaning is something only you, reading the cards later, would assign.

This worker is the CPU. The trays on the desk are registers. The warehouse is
memory (RAM). The stack of index cards is your program. That's genuinely most of
what's happening when any program runs — everything else (functions, variables,
strings, objects) is a story humans tell about clever arrangements of these index
cards, built up by compilers so you don't have to think at this level. When you
write assembly, you're writing the index cards directly.

Two things make this worker fast: the trays on the desk (registers) are close at
hand, so grabbing a number from one is nearly instant. The warehouse (memory) is
much bigger but slower to reach — walking to a shelf and back takes real time
compared to just picking up a tray. This is why CPUs try to keep active values in
registers as much as possible and only go to memory when they must.

There's one special index card position: the worker always remembers *which card
they're currently reading*. Most of the time, after finishing a card, they just
pick up the next one in the stack. But some cards say "stop, go read card #47
instead" — that's how loops and function calls work. The worker doesn't
understand "this is a loop," they're just following a card that says "jump to a
different card."

Finally: there's a special area of the warehouse set aside as scratch space,
organized like a stack of trays that only grows from one end — you can only add a
tray to the top or take the top tray off. This scratch space is used mostly for
"remembering where I was" when the worker temporarily goes off to follow a
different card sequence and needs to come back later. That's the stack. There's
also a totally separate area of the warehouse that isn't managed this way — it's
requested explicitly ("give me shelf space for 40 numbers") and stays reserved
until explicitly given back. That's the heap.

## Now with the real terms

- The **worker** is the CPU (central processing unit).
- The **trays on the desk** are **registers** — small, fixed-size storage
  locations built directly into the CPU chip. On x86-64 each register holds 64
  bits. There are only a handful of them (covered in Phase 2).
- The **warehouse** is **memory** (RAM) — a flat sequence of numbered locations
  (**addresses**), each holding a byte. Memory has no built-in types; the meaning
  of the bytes at an address is entirely a convention imposed by the instructions
  that read them. `char *str` is exactly this: "the value here is an address; go
  read bytes from there until you hit a zero byte, and that's your string."
- The **stack of index cards** is the program's **instructions**, stored in
  memory just like any other data, in the `.text` section of the binary.
- "Which card the worker is currently reading" is tracked by a special register
  called the **instruction pointer**, `rip` on x86-64. Normal execution
  auto-increments it to the next instruction. A **jump** instruction (`jmp`,
  or a conditional jump like `je`) is nothing more than the CPU overwriting `rip`
  with a different address instead of letting it increment.
- The **fetch → decode → execute** loop is the actual technical name for "worker
  reads a card, figures out what it means, does it, repeats" — this cycle,
  happening billions of times per second, is the entirety of what a CPU does.
- The **scratch space stack of trays** is **the stack**, a region of memory used
  mainly for function-call bookkeeping (return addresses, temporarily saved
  register values, local variables). It's managed by a dedicated register,
  `rsp` (the **stack pointer**), which always holds the address of the current
  top. Critically, the stack grows *downward*: pushing a value onto it
  *decreases* the address in `rsp`, which trips people up the first time they see
  it.
- The **separately-requested warehouse space** is **the heap** — memory obtained
  explicitly (in C, via `malloc`) that persists independently of function
  calls/returns, until explicitly released (`free`). No register automatically
  tracks heap allocations the way `rsp` tracks the stack; you keep track of heap
  addresses yourself, in registers or memory, for as long as you need them.
- A **function**, at this level, is just a **label** — a name attached to the
  address of some index card in the stack of cards. "Calling" a function means
  jumping `rip` there, while leaving a breadcrumb (on the stack) that lets
  execution find its way back to where it was — this breadcrumb mechanism is the
  entire subject of Phase 4.

## Deep dive

A few points worth sitting with, because they're easy to nod along to and still
not really internalize:

- **There is no "variable" at the CPU level.** When you write `int x = 5;` in C,
  the compiler decides, based on its own analysis, whether `x` lives in a
  register for a while, gets spilled to a stack slot, or both at different points
  in the function. In assembly, you make that decision yourself, explicitly,
  every time. This is the main reason assembly feels harder than C at first —
  it's not that the operations are more complex, it's that C was quietly making
  hundreds of small storage decisions for you that you now have to make
  yourself.
- **Memory addresses are just numbers you can do arithmetic on.** If a register
  holds the address `0x1000` and you add 1 to it, you now have the address of
  the *next byte* in memory. This is the entire basis of how strings, arrays, and
  pointer arithmetic work under the hood — `str + 1` in C compiles down to
  exactly this kind of address arithmetic.
- **The fetch-decode-execute cycle is why clock speed matters.** Every "tick" of
  the CPU's clock, in simplified terms, corresponds to progress through this
  cycle. A 3 GHz CPU is doing roughly 3 billion of these cycles per second (real
  CPUs pipeline and parallelize this heavily, but the mental model holds for our
  purposes).
- **Registers are not memory addresses.** This trips people up: you cannot ask
  "what is the memory address of `rax`?" — a register isn't *located* in the
  address space the way a memory location is. It's a separate, small pool of
  storage the CPU has immediate access to, addressed by name (`rax`, `rbx`, ...)
  in the instruction encoding itself, not by a numeric address.

## Checkpoint

**Q1: In the desk-and-warehouse analogy, what are the trays and what is the
warehouse, in real terms?**
<details><summary>Answer</summary>
Trays = registers (small, fast storage built into the CPU). Warehouse = memory /
RAM (a much larger but slower flat array of addressable byte storage).
</details>

**Q2: Why can't you ask "what memory address does `rax` live at"?**
<details><summary>Answer</summary>
Because registers aren't part of the memory address space at all — they're a
separate, small, named pool of storage the CPU accesses directly by name in the
instruction itself, not via an address lookup.
</details>

**Q3: What does memory having "no built-in types" actually mean in practice for
something like a C string?**
<details><summary>Answer</summary>
It means the bytes at a given address don't inherently "know" they represent
text. The interpretation — "read bytes from this address until a zero byte,
treat them as characters" — is a convention that the instructions operating on
that memory impose; the hardware has no concept of "string" at all.
</details>

**Q4: What does a jump instruction do at the register level, and which register
does it affect?**
<details><summary>Answer</summary>
It overwrites `rip` (the instruction pointer) with a new address, so the next
fetch reads from that new location instead of the next sequential instruction.
</details>

**Q5: Why does the stack grow downward, and what does "pushing" do to `rsp`
numerically?**
<details><summary>Answer</summary>
It's a convention baked into x86 (and most architectures) rather than a logical
necessity — but the practical consequence is that pushing a value *decreases*
`rsp` (moves it to a lower address), and popping *increases* it back.
</details>

**Q6: What's the key difference in how the stack and the heap are managed?**
<details><summary>Answer</summary>
The stack is managed automatically and implicitly by a dedicated register
(`rsp`) following push/pop discipline, tightly tied to function call/return. The
heap is explicitly requested and released (`malloc`/`free`) and nothing
automatically tracks its lifetime — you're responsible for remembering and
eventually freeing every allocation.
</details>
