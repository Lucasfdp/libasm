# Phase 7 — Toolchain Mechanics

## Plain-English first

Imagine you and several coworkers each write one chapter of a book, on separate
typewriters, using a shorthand only specialists can read. Before anyone can
actually read the finished book, three things need to happen: each shorthand
chapter needs to be translated into normal printed text (one chapter at a time,
independently), all the translated chapters need to be bound together in the
right order with all their internal cross-references (like "see chapter 3")
correctly resolved to actual page numbers, and — if you want to hand out just a
*reference volume* of some chapters for other people to bind into their own
books later, without including everything — you'd want a labeled box containing
just those translated chapters, with a table of contents on the box so someone
grabbing from it later only pulls out the specific chapters they actually need.

Finally, since retranslating every chapter from scratch every time you fix a
typo in just one of them would be wasteful, you'd want a system that only
retranslates the chapters that actually changed since last time, leaving the
others alone.

## Now with the real terms

- **nasm** is the "translate one shorthand chapter" step — it assembles a
  single `.s` file into a `.o` **object file**: real machine code, plus a
  symbol table recording which labels this file defines and which labels it
  references but expects to find elsewhere. It works on one file at a time and
  knows nothing about any other file.
- **ld** (the linker) is the "bind chapters together, resolve cross-references"
  step — it takes multiple `.o` files (and libraries), combines them into a
  final executable, and resolves every `extern`/`global` reference between them
  (so a `call ft_strlen` in `main.o` correctly ends up pointing at the actual
  `ft_strlen` label defined in `ft_strlen.o`). In practice, you'll invoke `ld`
  indirectly through `gcc`/`cc`, which knows how to call it with the right
  default startup files and system libraries already wired in — calling `ld`
  completely by hand is rarely necessary and easy to get subtly wrong.
- **ar** is the "labeled reference box" step — it packages multiple `.o` files
  into a single `.a` **static library archive**, with an index so the linker
  can later pull in just the specific object files a program actually needs
  from that archive, rather than being forced to include everything.
- Your **C `main`** links against `libasm.a` the same way any program links
  against any static library: `main.c` gets compiled to `main.o`, and then that
  object file is linked together with `libasm.a` to produce the final
  executable.
- The **Makefile** required rules: `$(NAME)` (builds the library itself),
  `all` (the default target when you just run `make`, typically depending on
  `$(NAME)`), `clean` (removes intermediate object files), `fclean` (removes
  object files *and* the final library — typically implemented as depending on
  or calling `clean` first, then removing the library too), and `re` (runs
  `fclean` then rebuilds from scratch). "Only recompile/relink only the
  necessary files" means each `.o` target should depend on its specific `.s`
  source file (and any shared headers), so `make`'s timestamp comparison
  correctly skips reassembling files that haven't changed.

## Deep dive

- **Object files are not yet runnable.** A `.o` file contains machine code, but
  any reference to a symbol defined in a different file is left as a
  placeholder ("relocation entry") until the linker fills it in with the
  symbol's actual final address. This is why you can successfully assemble a
  `.s` file that references an `extern` symbol that doesn't exist anywhere —
  `nasm` doesn't check that, only `ld` does, at link time, which is why a typo
  in an `extern` name typically shows up as a link error, not an assembly
  error.
- **Static libraries (`.a`) vs the alternative (dynamic/shared libraries,
  `.so`)**: a static library's object code gets physically copied into your
  final executable at link time. This project requires a static library
  (`libasm.a`), which is simpler to reason about for this purpose — there's no
  runtime loading step, the code is just part of your binary once linked.
- **Incremental builds depend entirely on correct Makefile dependencies.** If
  your rule for building `ft_strlen.o` doesn't actually list `ft_strlen.s` as a
  prerequisite, `make` has no way to know it needs rebuilding after you edit
  that file — it'll either always rebuild (wasteful) or never rebuild
  (incorrect) depending on how the rule is written. Getting this right is what
  the subject means by "must recompile/relink only the necessary files."
- **The bonus rule requirement is a Makefile detail worth planning for early**:
  the subject requires bonus functionality to live in separate `_bonus.{c/h}`
  (here, presumably `_bonus.s`/`.h` given this is an asm project) files, and to
  be built via a distinct `bonus` Makefile rule — meaning your Makefile
  structure should cleanly separate "mandatory object files" from "bonus object
  files" from the start, rather than retrofitting that separation later.

## Checkpoint

**Q1: What's the difference between what `nasm` produces and what `ld`
produces, in terms of "runnable-ness"?**
<details><summary>Answer</summary>
`nasm` produces object files (`.o`) containing machine code with unresolved
references to symbols defined elsewhere — not yet runnable on their own. `ld`
produces a fully linked executable (or library) with all cross-file references
resolved to actual addresses — runnable.
</details>

**Q2: If you write `extern ft_something` in an assembly file but never actually
define `ft_something` anywhere, at which step does that surface as an error —
assembling or linking — and why?**
<details><summary>Answer</summary>
Linking. `nasm` only checks that your own file's syntax and internal references
are valid; it doesn't verify that externally referenced symbols actually exist
anywhere. `ld` is the step that tries to resolve every reference across all
provided object files/libraries, and that's where a genuinely missing symbol
would be caught.
</details>

**Q3: What does `ar` produce, and why is it useful to bundle multiple `.o`
files this way instead of just handing someone a folder of loose `.o` files?**
<details><summary>Answer</summary>
It produces a `.a` static library archive — a single file containing multiple
object files plus an index. It's useful because the linker can then
selectively pull in only the specific object files actually needed by whatever
links against the archive, and it's simply more convenient to distribute and
reference as one file.
</details>

**Q4: For incremental rebuilds to work correctly, what must each `.o` target's
Makefile rule list as a prerequisite?**
<details><summary>Answer</summary>
Its corresponding `.s` source file (and any shared headers it depends on), so
`make` can compare timestamps and know to reassemble only when that specific
source file has actually changed.
</details>

**Q5: What should `fclean` do that `clean` alone doesn't?**
<details><summary>Answer</summary>
`clean` removes intermediate object files; `fclean` additionally removes the
final build artifact (the library itself), typically by depending on or
invoking `clean` first and then also deleting the library.
</details>
