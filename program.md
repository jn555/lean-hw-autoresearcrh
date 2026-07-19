# program.md — the autoresearch protocol

*This file is the loop. It is not documentation for building the project — that
is `CLAUDE.md`. This file is the protocol an autonomous coding agent follows when
**running** the loop. Adapted from [Karpathy's
autoresearch](https://github.com/karpathy/autoresearch) via
[autoresearch-mlx](https://github.com/trevin-creator/autoresearch-mlx).*

You are an autonomous researcher optimizing a hardware design. You propose a
circuit revision, prove it still implements the spec, synthesize it, and keep it
only if it is both **correct** and **cheaper**.

## Setup

1. **Agree a run tag** with the user (e.g. `jul18`). The branch
   `autoresearch/<tag>` must not already exist.
2. **Create the branch**: `git checkout -b autoresearch/<tag>`.
3. **Read the in-scope files**:
   - `lean/Spec/Alu.lean` — the specification. **Read-only.**
   - `lean/Equiv/Alu.lean` — the equivalence theorem. **Read-only.**
   - `lean/Impl/Alu.lean` — the circuit. **This is the only file you edit.**
   - `score.sh` — the scorer. **Read-only.**
4. **Establish your baseline**: run `./score.sh` once on the untouched
   implementation and record it. Do not use a number from anywhere else.
5. **Confirm and go.**

## What you can and cannot do

**You CAN** modify `lean/Impl/Alu.lean` — the circuit structure, gate choices,
sharing, encoding, the whole implementation. Anything that still proves.

**Interface contract** (the frozen proof and emitter depend on it):

- `Ratchet.Impl.out : Nat → Circuit` must exist; `out i` is output bit i.
- Input encoding: `.input 0`–`.input 7` are bits of `a` (LSB first),
  `.input 8`–`.input 15` are bits of `b`.
- Tag **every** definition you write `@[simp]`, or the frozen proof cannot
  unfold it and the build fails (that is a reject, never unsoundness).
- The file may contain only `import Dsl` as its import.

**You CANNOT:**

- Modify `lean/Spec/*` — the spec is ground truth.
- Modify `lean/Equiv/*` — you do not get to edit the thing that judges you.
- Modify `score.sh` or the Yosys script — the metric must stay comparable.
- Use `sorry`, `native_decide`, `axiom`, `unsafe`, `@[implemented_by]`,
  `partial`, `macro`, `elab`, `initialize`, or any `set_option` at all.
  `native_decide` is the trap: it looks like a proof but trusts the compiler
  rather than the kernel. `score.sh` enforces all of this by **substring**
  match on the file — comments included — so keep those words out entirely,
  and it audits `#print axioms` against an allowlist besides.
- Add dependencies.

## The two signals

`./score.sh` prints a summary and exits non-zero if the design is illegal:

```
proof:  PASS
axioms: CLEAN
cells:  40
```

On any violation it prints `proof: FAIL`, `cells: 0`, and a `reason:` line,
and exits non-zero.

- **`proof`** is a gate, not a score. `FAIL` means the circuit no longer
  implements the spec — revert, no exceptions, no matter how good the cell count
  looks.
- **`axioms`** must be `CLEAN`: only `propext`, `Classical.choice`,
  `Quot.sound`, plus `bv_decide`'s own `…._native.bv_decide.ax_*` (native
  execution of Lean's formally verified LRAT certificate checker — expected
  on every real `bv_decide` proof). Anything else means a proof was faked.
- **`cells`** is the objective. Lower is better.

**The metric is exact.** Yosys cell count is deterministic — the same circuit
always scores the same. There is no run-to-run noise here, so any improvement is
real and no statistical gating is needed. A tie is a tie, not a maybe.

**Simplicity criterion**: all else equal, simpler is better. A large cell-count
win that makes the circuit incomprehensible is worth less than it looks; a
simplification that ties on cells is worth keeping.

## The loop

**One experiment at a time, greedy, on one branch.** This is the standard
autoresearch flow and it is deliberately simple: no tree search, no population,
no backtracking to explore alternatives. Each iteration starts from the current
best and either advances it or is thrown away. Depth comes from volume — a
hundred sequential attempts overnight — not from breadth within an iteration.

Run on a dedicated branch. LOOP FOREVER:

1. Look at the git state — current branch and commit.
2. Revise `lean/Impl/Alu.lean` with an experimental idea.
3. `git add lean/Impl/Alu.lean && git commit -m "experiment: <description>"`
4. Run it: `./score.sh > run.log 2>&1` (redirect — do not flood your context).
5. Read the result: `grep "^proof:\|^axioms:\|^cells:" run.log`
6. If the output is empty or the build errored, read `tail -n 50 run.log`. A
   proof failure is a *normal outcome*, not a bug to fix — the circuit was
   wrong. Only debug when the harness itself broke.
7. If `proof: PASS`, `axioms: CLEAN`, and cells strictly improved (or tied
   with a clear simplification): it is a **keep** — leave the experiment
   commit in place.
8. Otherwise it is a **discard**: `git reset --hard HEAD~1` — the tip
   *before* your experiment commit. Never reset further back to the last
   kept commit: that also wipes the log commits made since it.
9. Either way, now append the row to `results.tsv` — citing the experiment
   commit hash from step 3 — and
   `git add results.tsv && git commit -m "loop: log <keep|discard> — <desc>"`.
   Never amend the experiment commit (amending changes the hash the row
   cites), and never silently drop an iteration.

**Timeouts**: a proof that does not finish is a reject, not a wait. If
`score.sh` exceeds its timeout, treat it as a failure and revert.

**Crashes**: if `score.sh` itself breaks (a Lake error, a missing file, a Yosys
parse failure), use judgment. Something dumb and local — a typo, a malformed DSL
term — fix and re-run. If the idea is fundamentally broken, log `crash` and move
on. Do not spend more than a few attempts on any one idea.

**Log everything.** Reject *reasons* are the most interesting output this loop
produces — a design that failed to prove is a more interesting data point than
one that merely scored worse. Never silently drop an iteration.

## Running it faster (operator notes)

**There is no model being trained here.** The only compute per iteration is a
Lean build plus a Yosys run — seconds to a minute on CPU. The "intelligence" in
the loop is the agent reading this file and proposing circuit revisions, which is
Claude Code itself. So the loop already runs on your Claude account; nothing
needs connecting.

Three levers that actually make it faster:

**1. Parallel branches — the standard way to widen the search.** More independent
runs, not a wider inner loop. Start several branches from the same baseline and
let each do its own greedy walk, then compare where they landed. The upstream MLX
port did this across three machines and found they converged on *different*
winners, which is the interesting result.

Use **git worktrees**, not multiple sessions in one directory — parallel agents
sharing a checkout will clobber each other's `Impl/Alu.lean` and fight over git
state:

```bash
git worktree add ../ratchet-a -b autoresearch/<tag>-a
git worktree add ../ratchet-b -b autoresearch/<tag>-b
```

Each worktree is its own directory with its own Lean build cache, so runs are
fully isolated. Point a separate agent session at each. Throughput scales close
to linearly; so does credit usage.

**2. Model choice.** Proposal quality matters less than proposal *volume* early
on, when there's obvious headroom. A faster model gets through more iterations
per hour; escalate to a stronger one when the loop starts stalling and the
remaining wins need real insight.

**3. Keep the build fast.** This is the per-iteration floor and it's easy to
wreck: no mathlib, small bit-widths, and a project small enough that incremental
rebuilds only touch `Impl/`. If an iteration starts taking minutes, fix that
before adding parallelism.

For genuinely unattended overnight runs, drive it with Claude Code in headless
mode (`claude -p`) from a shell loop rather than an interactive session.

Keep each branch a plain greedy walk. Do not turn the inner loop into a tree
search; that is a different project.

## results.tsv

Tab-separated, not comma-separated. Header plus five columns:

```
commit	cells	proof	status	description
a1b2c3d	168	PASS	keep	baseline ripple-carry
e4f5g6h	151	PASS	keep	share carry chain across bit slices
i7j8k9l	0	FAIL	discard	skip-carry shortcut — broke on carry-in edge case
m0n1o2p	149	PASS	discard	rewrote mux tree — correct but larger after synth
```

Use `0` for cells when the proof failed. Status is `keep`, `discard`, or
`crash`.

## Never stop

Once the loop has begun, do **not** pause to ask whether to continue. The human
may be asleep. You are autonomous — run until interrupted. If you run out of
ideas, think harder: re-read the spec for structure you haven't exploited, look
at what the rejected attempts had in common, try a different encoding, try
combining two near-misses, try a more radical restructuring. The loop runs until
the human stops it.
