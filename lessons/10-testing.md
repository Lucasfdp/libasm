# Phase 10 — Testing

## Plain-English first

Imagine you've built a scale replica of a bridge and you want to know if it's
actually sound before anyone drives over it. "It looks fine" isn't an answer —
you need to actually load it with weight, in various distributions, including
the awkward ones (all the weight on one edge, way more weight than expected,
literally zero weight), and see what happens each time, compared against what a
bridge you already trust would do under the same conditions.

Your functions are the bridge. The "bridge you already trust" is the real libc
— you already have access to genuinely correct, battle-tested implementations
of `strlen`, `strcmp`, `strcpy`, `write`, `read` sitting right there in the C
standard library. Testing, for this project, mostly means: run your version and
the real version on the same inputs, and check that they agree — including on
the awkward inputs, not just the easy ones.

## Now with the real terms

- **Differential testing against libc**: for each function, call both your `ft_`
  version and the real libc equivalent on identical inputs, and compare the
  results directly. This gives you an objective pass/fail rather than "this
  seems right," and it catches mismatches you wouldn't have thought to check by
  eye.
- **Edge cases worth deliberately covering**:
  - Empty strings (`""`).
  - Single-character strings.
  - Very large buffers — some bugs (loop boundary errors, anything that only
    manifests once you cross a particular size or alignment threshold) simply
    don't show up on short inputs.
  - For `ft_strdup` specifically: confirm the returned pointer is a genuinely
    distinct heap allocation, not somehow aliasing the input string.
- **Deliberately triggering the error path** for `ft_write`/`ft_read`: write to
  a closed or otherwise invalid file descriptor, read from one, and confirm
  both the return value (`-1`) and the resulting errno value match what the
  real syscalls/libc functions would produce for the same invalid input.
- **Keep the test harness around after submission.** The subject explicitly
  notes you're free to use your own tests (or a peer's) during the defense —
  this isn't throwaway scaffolding, it's part of how you'll demonstrate
  correctness live.

## Deep dive

- **"Looks right" is a weak signal because it only catches errors you already
  anticipated.** A direct comparison against an authoritative reference
  implementation catches everything the reference implementation would also
  handle differently — including cases you wouldn't have thought to construct
  by hand, simply because you're comparing outputs rather than reasoning about
  correctness from first principles each time.
- **Large-buffer tests specifically catch a category of bug that small tests
  structurally cannot.** If your loop has an off-by-one error that only
  matters once you cross, say, a 4KB boundary (perhaps because of how you're
  doing address arithmetic, or an assumption that happens to hold for small
  sizes), no amount of testing with 3-character strings will ever reveal it —
  you need at least one test case deliberately sized to cross whatever
  boundaries might be relevant.
- **Testing the error path is easy to skip and shouldn't be.** It's tempting
  to only test the "happy path" (valid inputs, successful syscalls) since
  that's what demonstrates the feature "working." But the subject explicitly
  requires correct error handling and errno-setting — untested error-handling
  code is unverified code, and it's exactly the kind of thing a defense
  evaluator is likely to probe directly by asking you to break your own
  function on the spot.
- **A reasonable test harness structure**: a small C `main` (separate from, or
  an extension of, the one required by the subject) that, for each function,
  runs a handful of fixed cases through both your implementation and the real
  libc function, and prints a clear pass/fail per case — rather than requiring
  you to manually eyeball raw output for correctness every time you rerun it.

## Checkpoint

**Q1: Why is "compare against real libc output" a stronger testing strategy
than "run it and see if the output looks reasonable"?**
<details><summary>Answer</summary>
Because eyeballing only catches mistakes you already suspect might be there.
Direct comparison against a trusted reference implementation catches any
discrepancy at all, including ones you wouldn't have thought to specifically
check for, without requiring you to anticipate every possible failure mode in
advance.
</details>

**Q2: Give a concrete reason a bug might only appear on a large input and never
on a 3-character test string.**
<details><summary>Answer</summary>
Some bugs are tied to crossing a specific size or address-alignment boundary
that a large-enough input reaches and a tiny one never does — for example, a
loop condition that's subtly wrong but happens to coincidentally produce the
correct result for very short inputs regardless of the mistake.
</details>

**Q3: How would you specifically construct a test to verify `ft_write`'s error
handling, and what two things would you check in the result?**
<details><summary>Answer</summary>
Call `ft_write` with a file descriptor known to be invalid (e.g. a closed fd or
a clearly invalid number), then check that the return value is `-1` and that
errno now holds the expected error code (e.g. matching what the real `write()`
syscall produces for the same invalid fd, such as `EBADF`).
</details>

**Q4: Why does the subject's note that you can use your own tests during the
defense make building a real test harness worth the extra time, even though
it's not separately graded?**
<details><summary>Answer</summary>
Because the defense is where correctness actually gets checked in front of an
evaluator, and having a ready, working set of tests you already trust means you
can demonstrate correctness (or catch a live-discovered bug) efficiently,
rather than improvising test cases on the spot under pressure.
</details>
