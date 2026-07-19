/- FROZEN. Run by score.sh: `lake env lean AxiomCheck.lean`.
   score.sh allowlists the output: propext, Classical.choice, Quot.sound,
   and bv_decide's own `<thm>._native.bv_decide.ax_*` (native execution of
   Lean's formally verified LRAT certificate checker). Anything else fails. -/

import Equiv.Alu

#print axioms Ratchet.Equiv.correct
