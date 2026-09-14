# Phase 6 — errno and Calling External C Functions

## Plain-English first

Continue the hotel analogy from Phase 5. When the front desk (the kernel) can't
fulfill a request, it doesn't just say "no" — it hands back a specific reason
code. But where does that reason code actually get *stored* so the guest can
look it up later, possibly after doing several other things first?

Every guest at the hotel has their own small personal mailbox behind the front
desk, used specifically for "the reason your most recent failed request
failed." It's not one shared mailbox for the whole hotel — if it were, and two
guests both had requests fail around the same time, they'd stomp on each
other's mailbox contents and get confused about whose failure reason belongs to
whom. So instead, there's a dedicated "which mailbox is yours" lookup: you ask
the front desk "where's my personal mailbox," they tell you a locker number, and
you go write (or read) your own reason code into that specific locker yourself.

That "ask where my mailbox is" step is itself a small request you make the
normal way — not through the special service-bell mechanism from Phase 5, but
through the ordinary "calling a coworker" mechanism from Phase 4, since this
particular lookup isn't a privileged kernel operation, just an ordinary
function you're allowed to call directly.

## Now with the real terms

- **`errno`** is the conventional name C programs use for "the reason the most
  recent failing library call failed." In modern C libraries it is not a single
  global variable shared by the whole process — it's **thread-local**, meaning
  each thread has its own private copy, specifically so that failures in
  different threads don't overwrite each other.
- Because it's thread-local (not just a fixed, predictable memory address), you
  can't simply hardcode an address to write into. Instead, the C library
  provides a function — **`__errno_location()`** on Linux, **`__error()`** on
  macOS (sometimes referenced with extra leading underscores due to how symbol
  names get mangled, e.g. `___error`) — that takes no arguments and **returns a
  pointer** to the calling thread's errno storage. You call it (following the
  ordinary calling convention from Phase 4, including stack alignment), receive
  an address back in `rax`, and then write your computed error code into the
  memory at that address yourself.
- This is a concrete, small example of a pattern you'll reuse for the rest of
  the project: calling an external C-ABI function correctly (respecting
  argument registers, alignment, and which registers it's free to clobber), then
  using whatever comes back in `rax` — here, treating it as a pointer and
  writing through it, rather than treating it as a final answer on its own.

## Deep dive

- **Why is `__errno_location` a function instead of a fixed global variable
  address?** Precisely because of thread-local storage: the real storage
  location for errno differs depending on which thread is currently running,
  and computing "which thread am I, and where's its errno slot" requires actual
  logic (typically involving a thread-local storage mechanism baked into how
  the OS and C library manage threads) — hence it has to be a function call,
  not a static address you could hardcode.
- **The call still has to obey the calling convention, even though it takes no
  arguments.** It's easy to assume "no arguments" means "no rules apply" — but
  stack alignment (Phase 4) is still required at the point of the `call`, and
  `rax`, along with the other caller-saved registers, is still considered fair
  game for this function to clobber. If you were relying on a caller-saved
  register to hold some other value across this call, you still need to save it
  first, exactly as with any other call.
- **Getting the pointer is only half the job.** A common mistake is calling
  `__errno_location`, getting an address in `rax`, and then... not actually
  writing anything through it, or writing the wrong-sized value. Errno is
  conventionally a 4-byte (`int`-sized) value, so writing through the returned
  pointer should typically move a 32-bit value (e.g. into the `dword` at that
  address), not accidentally write a full 8-byte quantity that could spill into
  adjacent memory.
- **macOS vs Linux naming**: if you ever need to support both, or you're reading
  mixed documentation/examples, keep straight that the symbol name differs
  (`__errno_location` vs `__error`) even though the underlying purpose — "give
  me a pointer to my thread's errno slot" — is identical. Using the wrong
  extern symbol name for your target OS will fail to link, which is at least a
  loud, easy-to-diagnose failure rather than a silent one.

## Checkpoint

**Q1: Why is errno a per-thread value rather than a single value for the whole
process?**
<details><summary>Answer</summary>
So that if multiple threads have failing calls around the same time, each
thread sees only the error from its own most recent failure, rather than
threads overwriting each other's error codes and producing confusing, racy
results.
</details>

**Q2: What does `__errno_location()` actually return — the error code itself,
or something else? What must you do with what it returns?**
<details><summary>Answer</summary>
It returns a pointer (an address) to the current thread's errno storage — not
the error code itself. You must then write your computed error code into the
memory at that address yourself; the function only tells you *where* to write,
it doesn't write anything for you.
</details>

**Q3: Does calling `__errno_location()` still require respecting stack
alignment, even though it takes no arguments? Why or why not?**
<details><summary>Answer</summary>
Yes. Stack alignment at the point of a `call` is a property of the calling
convention itself, unrelated to how many arguments a function takes — even a
zero-argument function is a normal `call`/`ret` pair and expects the same
16-byte alignment as any other call.
</details>

**Q4: If errno is conventionally an `int` (4 bytes), what's the risk of writing
a full 8-byte value through the pointer `__errno_location` returns?**
<details><summary>Answer</summary>
It could overwrite adjacent memory beyond the actual 4-byte errno slot,
potentially corrupting whatever else the C library stores immediately next to
it in that thread-local storage area — the write size should match the actual
size of the storage being written to.
</details>

**Q5: What's the practical consequence of using `__errno_location` (the Linux
symbol name) when building/linking on macOS?**
<details><summary>Answer</summary>
The link step would fail, since that exact symbol doesn't exist under that name
in macOS's C library — you'd need `__error` instead. This is a loud failure at
build time rather than a silent runtime bug, which at least makes it easy to
notice and fix.
</details>
