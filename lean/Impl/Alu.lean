/- THE ONLY FILE THE LOOP EDITS.

   Interface contract (the frozen proof depends on it):
   - `Ratchet.Impl.out : Nat → Circuit` must exist; `out i` is output bit i.
   - Input encoding: `.input 0`..`.input 7` = bits of `a` (LSB first),
     `.input 8`..`.input 15` = bits of `b`, `.input 16`..`.input 18` = op.
   - Every definition in this file must be tagged `@[simp]`, or the frozen
     proof cannot unfold it and the build fails (a reject, never unsound).
   - Only `import Dsl`. -/

import Dsl

namespace Ratchet.Impl

open Ratchet (Circuit)

@[simp] def aIn  (i : Nat) : Circuit := .input i
@[simp] def bIn  (i : Nat) : Circuit := .input (8 + i)
@[simp] def opIn (i : Nat) : Circuit := .input (16 + i)

/- Seed: every op gets its own datapath; both comparisons get their own
   dedicated comparator chains. Naive on purpose.
   op 000 add, 001 sub, 010 and, 011 or, 100 xor, 101 sltu, 110 slt, 111 nor. -/

@[simp] def carry : Nat → Circuit
  | 0     => .const false
  | i + 1 => .or (.and (aIn i) (bIn i))
                 (.and (carry i) (.xor (aIn i) (bIn i)))

@[simp] def addBit (i : Nat) : Circuit := .xor (.xor (aIn i) (bIn i)) (carry i)

@[simp] def borrow : Nat → Circuit
  | 0     => .const false
  | i + 1 => .or (.and (.not (aIn i)) (bIn i))
                 (.and (borrow i) (.not (.xor (aIn i) (bIn i))))

@[simp] def subBit (i : Nat) : Circuit := .xor (.xor (aIn i) (bIn i)) (borrow i)

@[simp] def andBit (i : Nat) : Circuit := .and (aIn i) (bIn i)
@[simp] def orBit  (i : Nat) : Circuit := .or (aIn i) (bIn i)
@[simp] def xorBit (i : Nat) : Circuit := .xor (aIn i) (bIn i)
@[simp] def norBit (i : Nat) : Circuit := .and (.not (aIn i)) (.not (bIn i))

/-- Unsigned a < b, LSB-up chain, dedicated to sltu. -/
@[simp] def ultC : Nat → Circuit
  | 0     => .const false
  | i + 1 => .or (.and (.not (aIn i)) (bIn i))
                 (.and (.not (.xor (aIn i) (bIn i))) (ultC i))

/-- A second, independent comparator chain, dedicated to slt. -/
@[simp] def ultS : Nat → Circuit
  | 0     => .const false
  | i + 1 => .or (.and (.not (aIn i)) (bIn i))
                 (.and (.not (.xor (aIn i) (bIn i))) (ultS i))

/-- Signed a < b: signs differ → a is the negative one; else unsigned order. -/
@[simp] def sltRes : Circuit :=
  .or (.and (aIn 7) (.not (bIn 7)))
      (.and (.not (.xor (aIn 7) (bIn 7))) (ultS 8))

@[simp] def sltuBit : Nat → Circuit
  | 0 => ultC 8
  | _ => .const false

@[simp] def sltBit : Nat → Circuit
  | 0 => sltRes
  | _ => .const false

/-- s = true selects x. -/
@[simp] def mux (s x y : Circuit) : Circuit := .or (.and s x) (.and (.not s) y)

@[simp] def out (i : Nat) : Circuit :=
  mux (opIn 2)
    (mux (opIn 1) (mux (opIn 0) (norBit i) (sltBit i))
                  (mux (opIn 0) (sltuBit i) (xorBit i)))
    (mux (opIn 1) (mux (opIn 0) (orBit i) (andBit i))
                  (mux (opIn 0) (subBit i) (addBit i)))

end Ratchet.Impl
