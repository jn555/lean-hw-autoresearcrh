/- FROZEN. The equivalence theorem and its generic proof script.
   The loop supplies circuits; it never writes proofs. If `simp` cannot fully
   unfold the implementation (e.g. a helper def missing `@[simp]`), the build
   fails — that costs progress, never soundness. -/

import Std.Tactic.BVDecide
import Spec.Alu
import Impl.Alu

namespace Ratchet.Equiv

open Ratchet

/-- Input encoding, shared with the emitter: 0-7 = a (LSB first), 8-15 = b. -/
def env (a b : BitVec 8) : Nat → Bool :=
  fun n => if n < 8 then a.getLsbD n else b.getLsbD (n - 8)

/-- The 8-bit word the implementation computes (bit 7 down to bit 0). -/
def result (a b : BitVec 8) : BitVec 8 :=
  BitVec.ofBool ((Impl.out 7).eval (env a b)) ++
  BitVec.ofBool ((Impl.out 6).eval (env a b)) ++
  BitVec.ofBool ((Impl.out 5).eval (env a b)) ++
  BitVec.ofBool ((Impl.out 4).eval (env a b)) ++
  BitVec.ofBool ((Impl.out 3).eval (env a b)) ++
  BitVec.ofBool ((Impl.out 2).eval (env a b)) ++
  BitVec.ofBool ((Impl.out 1).eval (env a b)) ++
  BitVec.ofBool ((Impl.out 0).eval (env a b))

/-- THE GATE: the circuit implements the spec, for all inputs. -/
theorem correct (a b : BitVec 8) : result a b = Spec.alu a b := by
  simp [result, env, Spec.alu, Circuit.eval]
  bv_decide

end Ratchet.Equiv
