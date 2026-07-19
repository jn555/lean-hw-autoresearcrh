# Ratchet — an autoresearch loop for hardware design

*Codename because the loop only ever moves forward: wins are committed, losses
are reverted. Rename freely — but **not** to "Anvil", which is already a
[real timing-safe HDL](https://arxiv.org/abs/2503.19447) and would confuse anyone
hardware-adjacent.*

A standard Karpathy-style autoresearch loop, pointed at hardware. The spec is a
mathematical function in Lean. The implementation is a circuit in a Lean HDL DSL.
An agent proposes revisions; each must **prove equivalent to the spec** to be
legal, and **synthesize to fewer cells** to be kept.

Two machine-produced signals: a Lean equivalence proof that **gates**, and a
Yosys cell count that **ranks**.

---

## Two files, two jobs — don't mix them

| File | Audience | Purpose |
|---|---|---|
| **`CLAUDE.md`** (this file) | Claude Code **building** the project | Architecture, environment, conventions, delegation |
| **`program.md`** | The agent **running** the loop | The autoresearch protocol: what's editable, the metric, the keep-or-revert steps |

This separation is the framework's own convention, and it matters: `program.md`
is the loop. Everything about *how to run experiments* belongs there; everything
about *how to build the thing* belongs here.

---

## The framework we're implementing

[Karpathy's autoresearch](https://github.com/karpathy/autoresearch), in the shape
of the [autoresearch-mlx](https://github.com/trevin-creator/autoresearch-mlx)
port.

**We adopt its protocol, not its code.** There is nothing in that repo to import:
`train.py` and `prepare.py` are a nanoGPT training run on MLX, and `rigor.py`
solves a noise problem we don't have. What we take is the *shape* — which is the
valuable part, and is why the loop is recognizable to anyone who's seen the
original.

Its key structural fact, verified by reading it: **there is no Python loop
driver.** The loop is the *coding agent itself* following `program.md` — edit one
file, commit, run the scorer, keep or `git reset --hard`. Four moving parts, and
we mirror all four:

| autoresearch-mlx | Ratchet |
|---|---|
| `train.py` — the one editable file | `lean/Impl/Alu.lean` — the circuit |
| `prepare.py` — frozen, holds `evaluate_bpb` | `lean/Spec/`, `lean/Equiv/`, `score.sh` — frozen |
| metric: `val_bpb` | metric: **proof PASS/FAIL** (gate) + **cell count** (objective) |
| `program.md` — the protocol | `program.md` — same, adapted |
| `results.tsv` — the log | `results.tsv` — same |
| fixed 5-minute training budget | fixed synthesis script + proof timeout |

**One difference worth stating out loud.** autoresearch-mlx needs `rigor.py` — a
bootstrap-over-seeds gate — because re-running the same `train.py` moves
`val_bpb` by ~0.03, so single-run deltas chase noise and the recorded curve is an
optimistic running minimum. **We don't need it.** Yosys cell count is
deterministic and the Lean kernel is binary, so every accepted improvement is
exactly real. That's the cleanest advantage of picking a domain with an exact
verifier, and it's worth a slide.

---

## Layout

Keep it as small as the framework's own repo. One editable file, one frozen
scorer.

```
lean/
  lakefile.toml
  Spec/Alu.lean       # the mathematical spec                    [FROZEN]
  Impl/Alu.lean       # the circuit — THE ONLY AGENT-EDITED FILE
  Equiv/Alu.lean      # equivalence theorem + generic proof       [FROZEN]
score.sh              # lake build → axiom check → Verilog → yosys  [FROZEN]
program.md            # the loop protocol
results.tsv           # the log
```

`score.sh` is the analog of `prepare.py`: it holds the ground-truth metric, and
it is read-only to the loop. It should print `proof:`, `axioms:`, `cells:` and
exit non-zero on any violation. Have it enforce the banned tokens
(`sorry`, `native_decide`, `axiom`, `unsafe`, weakening `set_option`s) and the
`#print axioms` check directly, so the protocol can't be violated by a
well-meaning agent.

**Aim for a generic proof script.** If `Equiv/` closes equivalence for *any*
circuit term (`intro x; simp [eval]; bv_decide`), the agent never writes proofs
at all — it supplies circuits and correctness is push-button. Worth designing the
DSL around.

---

## The DSL decision

[Sparkle](https://github.com/Verilean/sparkle) is the strong candidate. Verified
by cloning it (2026-07-18):

- **It emits Verilog** — `Sparkle/Backend/Verilog.lean` (303 lines) exposes
  `toVerilog`, `toVerilogDesign`, `writeVerilogFile`; the README documents a
  `#synthesizeVerilog` macro. No emitter of our own needed.
- **Dependencies are light** — one entry in `lake-manifest.json` (LSpec, a test
  framework). **No mathlib**, so rebuilds stay fast.
- **It already expects our tooling** — `shell.nix` lists `yosys` and `verilator`;
  it ships a Verilator co-simulation backend, `Backend/CSim.lean`,
  `Backend/VCD.lean`.
- **Far past "educational"** — 919 Lean files, a `Verification` module, an
  RV32IMA SoC that reportedly boots Linux with 102 theorems.
- **Toolchain**: pins `leanprover/lean4:v4.28.0` while 4.32.0 is installed; elan
  fetches it automatically. Budget a few minutes for first build.

**The open question is not synthesis — it's proving.** Sparkle is built for
simulation and synthesis, which does not mean its Signal semantics *reduce under
`simp` far enough for `bv_decide` to bitblast*. That is the spike.

**Fallback:** a ~100-line in-house DSL — an inductive for combinational gates, a
`step` for sequential, plus a small Verilog emitter. Not a defeat; often faster
than bending an unfamiliar library, and it keeps the semantics shaped for proofs.

---

## Combinational first, sequential second

Combinational equivalence (`∀ inputs, eval impl x = spec x`) is a bitvector goal
`bv_decide` closes directly. Stream equivalence is induction over time and is
**not** push-button — it decomposes into a refinement argument: supply a relation
`R` between spec and impl state, then prove initial states related, `R` preserved
by one step, outputs agree under `R`. Obligations 2 and 3 are per-step and
finite, so `bv_decide` handles them again. Cheaper intermediate: bounded
equivalence, unrolling k cycles.

**Incompleteness is safe.** A missed invariant rejects a good design — it costs
progress, never soundness.

---

## The trust gap

The proof is about the **DSL term**; the score comes from **emitted Verilog**. A
buggy emitter means proving one circuit and measuring another. Mitigation:
**co-simulate** — random vectors through the Lean semantics and through the
Verilog under `iverilog`, assert agreement. Not a proof, but it catches emitter
bugs, and it's honest to state plainly: *the kernel guarantees impl ≡ spec; the
emitter is trusted code, cross-checked by co-simulation.*

---

## Environment (verified 2026-07-18)

Everything needed is installed. No setup work.

| Tool | Version | Notes |
|---|---|---|
| Lean / Lake | **4.32.0** / 5.0.0 (elan) | Past 4.12, so `bv_decide` + bundled CaDiCaL available |
| Yosys | **0.57** | ABC bundled |
| Icarus Verilog | **13.0** | For co-simulation |

**Not a git repo yet** — `git init` is step zero, since git is the keep-or-revert
mechanism.

Useful Yosys shapes: `read_verilog f.v; synth; abc -g AND,OR,XOR,NAND,NOR,NOT;
stat` for technology-neutral cell counts (good default). With a liberty file,
`abc -liberty cells.lib -D <ps>; stat -liberty` gives area under a timing
constraint; `abc9` is delay-aware if depth becomes the objective.

---

## Gotchas

- **Keep dependencies minimal.** `BitVec` and `bv_decide` (`Std.Tactic.BVDecide`)
  are in Lean core — **do not add mathlib**, it destroys the iteration rate.
- **`bv_decide` needs a concrete bitvector goal.** A deep-embedded `eval` must be
  fully unfolded first — `simp [eval, ...]` until the goal is plain `BitVec`,
  *then* `bv_decide`. "Unsupported term" almost always means the interpreter
  didn't reduce: a modeling problem, not a SAT problem.
- **`bv_decide` does not do induction** and does not handle unbounded `Nat`.
- **SAT blows up on multipliers.** Adders, comparators, muxes: easy. 8×8
  multiply: borderline. Keep widths ≤ 8 to start.
- **Pin the toolchain and the Yosys script.** Both affect comparability.
- **Seed something with real headroom.** A hand-optimized starting circuit leaves
  the loop nothing to find. Start deliberately naive.

---

## Working agreements

- **Never claim a proof works without a clean `lake build`.** Paste real output.
- **Never report a loop result that isn't in `results.tsv`.**
- **Test the gates before trusting them.** Feed a deliberately wrong
  implementation and confirm rejection. An untested gate is not a gate.
- **Working spine over polish.** A closed loop on a trivial circuit beats an
  elegant DSL with no loop around it.
- **Treat the frozen files as invariants** — never weaken one to make an
  iteration pass. A loop that can cheat has no result.

---

## Model delegation — Fable orchestrates, hand work *down the chain*

The subagents in `.claude/agents/` are general-purpose and pinned to descending
model tiers. Route by difficulty, not habit.

| Task | Agent | Model |
|---|---|---|
| Highest-stakes **design & analysis**: DSL choice, semantics shape, refinement framework, soundness of the gate | **`architect`** | Fable |
| **Judgment-heavy implementation**: the DSL and its proofs, `score.sh`, the emitter | **`implementer`** | Opus |
| **Adversarial review**: can the loop cheat? are frozen files frozen? does the score reflect the proven circuit? | **`reviewer`** | Opus |
| **Well-specified single pieces**: one circuit variant, one metric, one script | **`builder`** | Sonnet |
| **Research / lookup**: Lean & `bv_decide` API, Sparkle evaluation, Yosys flags | **`explorer`** | Sonnet |
| **Run & verify**: execute the loop, check determinism, regression-check proofs | **`tester`** | Sonnet |
| **Docs & prose**: README, demo script, results write-up | **`scribe`** | Haiku |
| **Mechanical chores**: renames, import fixes, formatting | **`janitor`** | Haiku |

**Routing principles**

- **Delegate down as far as difficulty allows.** A rename is Haiku work; choosing
  the DSL is not.
- **Lean proof debugging is `implementer` work, not `builder` work** — a failing
  `bv_decide` is usually a modeling problem in mechanical disguise.
- **Give subagents a crisp, self-contained brief**; they don't share your context.
- **Parallelize independent work** — e.g. `explorer` evaluating Sparkle while
  `implementer` writes `score.sh` against a stub.
- **Escalate on uncertainty.** A wrong DSL choice is the most expensive mistake
  available on build day.
- **The orchestrator owns integration and the final call.**
