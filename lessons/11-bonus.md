# Phase 11 — Bonus (Only After Mandatory Is Airtight)

The subject is explicit and unambiguous about the gate here: bonus is only
evaluated if the mandatory part is *perfect* — integrally done, no
malfunctioning. Don't open this phase until Phase 10 has given you real
confidence, not just "it compiles and the demo works."

## Plain-English first

`ft_atoi_base` is really just a more particular version of a skill you already
have: reading a string carefully and being strict about what counts as valid
input before you trust it.

The linked-list functions are a bigger conceptual jump, so it's worth
introducing the shape of the problem before the mechanics: a linked list is a
chain of boxes, where each box holds one piece of data plus a note pointing to
the location of the next box in the chain (or a note saying "this is the last
box"). In C, the compiler tracks "where's the data field, where's the next
field" for you automatically whenever you write `node->data` or `node->next`.
In assembly, there is no compiler doing that for you anymore — you have to know,
and explicitly compute, exactly how many bytes into the box each field sits.

And the trickiest new idea in this phase: a couple of these functions receive,
as an argument, the *address of a function you don't know in advance* (a
comparison function, or a free function) — and you're expected to actually jump
to and execute whatever function that address points to, in the middle of your
own function's logic, then come back and continue.

## Now with the real terms

### `ft_atoi_base`
Parses the initial portion of a string as an integer in an arbitrary base
(rather than assuming base 10), given the base's digit characters as a second
string argument. Before doing any conversion, the base string itself must be
validated: it must be at least 2 characters long, contain no duplicate
characters, and contain none of `+`, `-`, or whitespace characters — any
violation means returning `0` immediately. Aside from the base handling, the
function should otherwise behave like the standard `atoi`. This is a good entry
point into bonus work because it introduces no new assembly *mechanics* beyond
what Phase 9 already covered — it's purely more careful string-parsing logic.

### The `t_list` struct and field offsets
```
typedef struct s_list
{
    void            *data;
    struct s_list   *next;
} t_list;
```
On a 64-bit system, `data` (a pointer) occupies the first 8 bytes of the
struct, and `next` (also a pointer) occupies the next 8 bytes, starting at
**byte offset 8**. Where C lets you write `node->next`, in assembly you write
the equivalent of "read/write the 8 bytes at address `(node's address) + 8`" —
you (or a symbolic constant you define for readability) are responsible for
knowing that offset is correct, since nothing checks this for you the way a C
compiler's type system would.

### `ft_list_push_front`
Takes a `t_list **begin_list` — a pointer *to* the variable that holds the
list's head pointer, not the head pointer itself. This double-pointer
indirection exists so the function can update *which node is the head* from
inside the function and have that change visible to the caller. Concretely:
reading the current head means dereferencing `begin_list` once to get the
current head node's address; updating the head means writing a new node's
address into the memory location `begin_list` itself points at. Getting single
vs. double dereference confused here — reading when you meant to write, or
computing one level of indirection short — is the single most common bug in
this function.

### `ft_list_size`
Walks the chain from `begin_list`, following each node's `next` field, counting
nodes until it reaches a node whose `next` is a null pointer, and returns the
count. Structurally, this is the same loop shape as `ft_strlen`, just walking
struct-to-struct via the `next` offset instead of byte-to-byte.

### `ft_list_sort`
Sorts the list in place, in ascending order, using a caller-provided comparison
function `cmp`, called as `(*cmp)(list_ptr->data, list_other_ptr->data)` for
each pair being compared. The new mechanic: `cmp`'s actual address arrives as a
runtime argument (you don't know it at assembly time — it might be `ft_strcmp`,
or anything else the caller chooses), so your code must `call` through that
address value itself, following the ordinary calling convention (Phase 4) to
set up `cmp`'s two arguments correctly and to interpret its return value the
same way `ft_strcmp` does (negative, zero, or positive).

### `ft_list_remove_if`
Walks the list removing every node whose `data`, compared against a given
`data_ref` via a caller-provided `cmp`, causes `cmp` to return `0`. The
`data` belonging to any removed node must be freed via a second
caller-provided function pointer, `free_fct`, called as
`(*free_fct)(list_ptr->data)`. This combines the "call an unknown function
pointer" mechanic from `ft_list_sort` with needing to correctly reconnect the
chain around a removed node (i.e., updating the *previous* node's `next` field
— or the head, if removing the first node — to skip over the removed node)
while also freeing memory as you go, without freeing the node structure itself
prematurely or leaking it.

## Deep dive

- **Why calling a function pointer through an argument specifically stresses
  your Phase 4 knowledge**: the function at the other end of that pointer is
  written by someone else (or generic code like `ft_strcmp`), with no idea what
  your list-traversal loop's internal register usage looks like. It's only
  obligated to preserve callee-saved registers. Any list-traversal state (the
  current node pointer, the previous node pointer, a running count) that you're
  keeping in a *caller-saved* register at the moment you `call` through `cmp`
  or `free_fct` is at real risk of being clobbered — meaning this state either
  needs to live in a callee-saved register across the call, or be reloaded from
  memory afterward rather than trusted to have survived in a register.
- **Offset arithmetic errors are silent, not crashing, in a specific dangerous
  way**: if you get the `next` offset wrong by using, say, offset 0 instead of
  8, you won't necessarily crash immediately — you might just silently read
  `data` where you meant to read `next`, producing a wrong-but-plausible-looking
  pointer that only causes a crash (or worse, appears to "work" on some inputs)
  much later, far from the actual mistake. Defining the offsets once as named
  constants at the top of your file, rather than scattering bare numbers
  through your code, makes this class of mistake much easier to catch and fix
  in one place.
- **The evaluation gate is a strong argument for genuinely finishing Phase 10
  first.** Since bonus isn't even looked at unless mandatory is perfect, time
  spent starting bonus work before mandatory testing is solid is a real risk —
  not just of wasted effort, but of bonus work distracting attention from
  finding a mandatory-part bug that would zero out the bonus evaluation
  regardless of how good the bonus code is.

## Checkpoint

**Q1: List two conditions that make a base string invalid for
`ft_atoi_base`.**
<details><summary>Answer</summary>
Any two of: fewer than 2 characters, containing duplicate characters,
containing `+`, containing `-`, or containing a whitespace character.
</details>

**Q2: At what byte offset from the start of a `t_list` node does the `next`
field live, and why specifically that number?**
<details><summary>Answer</summary>
Offset 8. Because `data` is a pointer (`void *`), which occupies 8 bytes on a
64-bit system, `next` begins immediately after those first 8 bytes.
</details>

**Q3: `ft_list_push_front` receives `t_list **begin_list`. Explain, in terms of
dereference depth, the difference between "read the current head" and "update
the head" inside this function.**
<details><summary>Answer</summary>
Reading the current head means dereferencing `begin_list` once — the value
stored at the address `begin_list` points to is the current head node's
address. Updating the head means writing a new value into that same memory
location (the one `begin_list` points at) — the parameter itself is already
the address of the head-pointer variable, so writing to update it needs to
target `[begin_list]`, not some further level of indirection.
</details>

**Q4: Why does calling the `cmp` function pointer inside `ft_list_sort` put
your callee-saved register discipline to a real test?**
<details><summary>Answer</summary>
Because `cmp` is a function you don't control, arriving as a runtime address,
and it's only obligated to preserve callee-saved registers per the calling
convention. Any traversal state you're keeping in a caller-saved register at
the moment of that call is at risk of being overwritten, so such state must
either live in a callee-saved register or be reloaded from memory after the
call rather than trusted to survive it.
</details>

**Q5: Why is a wrong struct-field offset a particularly dangerous kind of bug,
compared to, say, an off-by-one in a simple counting loop?**
<details><summary>Answer</summary>
Because it doesn't necessarily crash immediately — it silently reads or writes
the wrong field, producing a value that looks like a plausible pointer or piece
of data, and the resulting misbehavior (or crash) can surface much later and
far away from the actual site of the mistake, making it harder to trace back.
</details>

**Q6: Why is it risky to start on bonus functions before mandatory testing
(Phase 10) is genuinely solid, beyond just "you might waste time"?**
<details><summary>Answer</summary>
Because bonus evaluation is entirely gated on the mandatory part being perfect
— time and attention spent on bonus work can distract from finding a
mandatory-part bug that, left unfixed, would cause the bonus work to not even
be evaluated at all, regardless of its own quality.
</details>
