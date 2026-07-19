#!/usr/bin/env bash
# =============================================================================
# Ratchet frozen scorer — READ-ONLY to the loop. Analog of autoresearch-mlx's
# prepare.py: it holds the ground-truth metric and the legality gates.
#
# Prints exactly:
#   proof:  PASS|FAIL
#   axioms: CLEAN|-
#   cells:  <n>        (0 when the design is illegal)
#   reason: <text>     (only on failure)
# Exits non-zero on any violation.
#
# Stated honestly: score.sh and frozen.sha256 cannot hash-check themselves —
# git history is the audit trail for those two. lean/Emit.lean is trusted
# code; an iverilog co-simulation cross-check of the emitter is future work.
# =============================================================================
set -u
cd "$(dirname "$0")"

fail() {
  echo "proof:  FAIL"
  echo "axioms: -"
  echo "cells:  0"
  echo "reason: $1"
  exit 1
}

# ---- 1. frozen-file integrity ----------------------------------------------
shasum -a 256 --status -c frozen.sha256 \
  || fail "frozen file modified (run: shasum -a 256 -c frozen.sha256)"

# ---- 2. banned tokens in the one editable file ------------------------------
# Substring match on purpose, comments included: keep these words out entirely.
if grep -nE 'sorry|native_decide|axiom|unsafe|implemented_by|partial|set_option|ofReduceBool|trustCompiler|macro|elab|initialize' lean/Impl/Alu.lean; then
  fail "banned token in lean/Impl/Alu.lean (lines above)"
fi
if grep -nE '^[[:space:]]*import' lean/Impl/Alu.lean | grep -vE 'import[[:space:]]+Dsl[[:space:]]*$'; then
  fail "lean/Impl/Alu.lean may only 'import Dsl'"
fi

# ---- 3. build = the proof gate ----------------------------------------------
if ! (cd lean && lake build) > build.log 2>&1; then
  tail -n 30 build.log
  fail "lake build failed — proof did not close or file did not elaborate"
fi

# ---- 4. axiom allowlist ------------------------------------------------------
ax_out=$( (cd lean && lake env lean AxiomCheck.lean) 2>&1 ) \
  || { echo "$ax_out"; fail "axiom check did not run"; }
ax_flat=$(printf '%s' "$ax_out" | tr '\n' ' ')
case "$ax_flat" in
  *"'Ratchet.Equiv.correct' depends on axioms:"*) ;;
  *) echo "$ax_out"; fail "unexpected axiom-check output" ;;
esac
ax_list=$(printf '%s' "$ax_flat" \
  | sed -n 's/.*depends on axioms: \[\(.*\)\].*/\1/p' \
  | tr ',' '\n' | sed 's/^ *//; s/ *$//' | sed '/^$/d')
bad=""
while IFS= read -r ax; do
  case "$ax" in
    propext|Classical.choice|Quot.sound) ;;
    # bv_decide natively executes Lean's formally verified LRAT certificate
    # checker and records that as this axiom. Expected and allowed. Anything
    # else (sorryAx, ofReduceBool, ._native.decide.ax_* from native_decide)
    # falls through to "disallowed".
    Ratchet.Equiv.correct._native.bv_decide.ax_*) ;;
    *) bad="$bad $ax" ;;
  esac
done <<EOF
$ax_list
EOF
[ -z "$bad" ] || { echo "$ax_out"; fail "disallowed axiom(s):$bad"; }

# ---- 5. emit Verilog ---------------------------------------------------------
mkdir -p lean/build
if ! (cd lean && lake env lean Emit.lean) >> build.log 2>&1; then
  tail -n 20 build.log
  fail "verilog emission failed"
fi
[ -s lean/build/alu.v ] || fail "emitter produced no Verilog"

# ---- 6. synthesize + count ---------------------------------------------------
if ! yosys -p "read_verilog lean/build/alu.v; synth; abc -g AND,OR,XOR,NAND,NOR; opt_clean; stat" > yosys.log 2>&1; then
  tail -n 20 yosys.log
  fail "yosys failed"
fi
cells=$(grep -E '^ *[0-9]+ cells$' yosys.log | tail -1 | awk '{print $1}')
[ -n "$cells" ] || fail "could not parse cell count from yosys.log"

echo "proof:  PASS"
echo "axioms: CLEAN"
echo "cells:  $cells"
