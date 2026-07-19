# Kickoff prompt — paste into a fresh session

---

Read `CLAUDE.md` first — it has the architecture, the environment (Lean 4.32,
Yosys 0.57, iverilog: all installed; not yet a git repo), and the framework we're
implementing.

We're building **Ratchet**: a Karpathy-style autoresearch loop pointed at
hardware design. The spec is a mathematical function in Lean. The implementation
is a circuit in a Lean HDL DSL. An agent proposes revisions; each must **prove
equivalent to the spec** to be legal and **synthesize to fewer cells** to be
kept.

We follow the [autoresearch-mlx](https://github.com/trevin-creator/autoresearch-mlx)
shape exactly, which is worth internalizing before you design anything: **there
is no Python loop driver.** The loop is a coding agent following `program.md` —
edit one file, commit, run the scorer, keep or `git reset --hard`. So we need
four things and nothing more: one editable file (`lean/Impl/Alu.lean`), one
frozen scorer (`score.sh`), `program.md`, and `results.tsv`.

Today's goal: **that loop closed on one combinational circuit** — an 8-bit ALU or
adder. Working spine over polish.

**Spike before building.** One unknown decides the architecture. Time-box to ~45
minutes and report back before continuing:

Can `bv_decide` close `∀ x, eval <concrete circuit term> x = spec x` for a
*deep-embedded* circuit, after `simp` unfolds the interpreter? Test two ways, in
parallel:

1. **Throwaway file** — three gates, a minimal `eval`, that theorem. Tells you the
   pattern works at all, and what the goal looks like if `simp` fails to reduce.
2. **[Sparkle](https://github.com/Verilean/sparkle)** — already confirmed to emit
   Verilog (`Sparkle/Backend/Verilog.lean`: `toVerilog`, `writeVerilogFile`),
   depend only on LSpec (no mathlib), and expect yosys/verilator. So the open
   question is *not* whether it synthesizes — it's whether its Signal semantics
   reduce far enough for `bv_decide` to close an equivalence goal. Built for
   simulation and synthesis ≠ shaped for bitblasting. It pins Lean v4.28.0, so
   elan will fetch that toolchain.

If Sparkle's semantics cooperate, use it and skip writing an emitter. If they
fight you, fall back to a ~100-line in-house DSL plus a small Verilog emitter —
a fine outcome, not a defeat. Don't sink an hour into someone else's library.

Then build in this order, verifying each step runs before the next:

1. `git init` + Lake skeleton, minimal dependencies.
2. `lean/Spec/Alu.lean` (frozen spec), `lean/Impl/Alu.lean` (the circuit), and
   `lean/Equiv/Alu.lean` — the equivalence theorem with a **generic** proof
   script that closes for *any* circuit term. The agent must never write proofs,
   only supply circuits.
3. `score.sh` — the frozen scorer, analog of mlx's `prepare.py`. It runs
   `lake build`, checks `#print axioms` is clean, greps for banned tokens
   (`sorry`, `native_decide`, `axiom`, `unsafe`, weakening `set_option`s), emits
   Verilog, runs Yosys, and prints `proof:` / `axioms:` / `cells:`. Non-zero exit
   on any violation. Add the `iverilog` co-simulation check here too — the proof
   is about the Lean term while the score comes from Verilog, so something must
   guard that seam.
4. Adapt `program.md` (already drafted — check it matches what you actually
   built: file paths, `score.sh` output format, the metric).
5. **Test the gates**: feed a deliberately wrong implementation and confirm
   `score.sh` rejects it; feed one with `sorry` and confirm the same. An untested
   gate is not a gate.
6. Seed a deliberately naive circuit for real headroom, then run the loop
   yourself for ~10 iterations following `program.md`, and show me `results.tsv`.

Use the subagents in `.claude/agents/`: `implementer` for the Lean work and
`score.sh`, `explorer` to evaluate Sparkle in parallel with the throwaway spike,
`tester` to run things and report real output, `reviewer` before the demo.
Escalate to `architect` if a design question turns out to be load-bearing.

Non-negotiable:

- No `sorry`, `native_decide`, `axiom`, `unsafe`, or checking-weakening
  `set_option` — and `score.sh` must enforce this rather than trusting anyone.
  `#print axioms` should show only `propext`, `Classical.choice`, `Quot.sound`.
- **Never report a result you didn't see.** Paste real `lake build` output and
  real `results.tsv` rows. If something doesn't compile or the loop accepts
  nothing, say so plainly — a negative result is worth more than a confident
  guess.

Done for this session = following `program.md` visibly produces keeps and
discards, and every `keep` row in `results.tsv` is a git commit whose proofs
check clean and whose cell count went down.
