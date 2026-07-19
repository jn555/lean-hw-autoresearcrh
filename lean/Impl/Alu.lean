/- THE ONLY FILE THE LOOP EDITS.

   Interface contract (the frozen proof depends on it):
   - `Ratchet.Impl.out : Nat → Circuit` must exist; `out i` is output bit i.
   - Input encoding: `.input 0`..`.input 7` = bits of `a` (LSB first),
     `.input 8`..`.input 15` = bits of `b`, `.input 16`..`.input 17` = op.
   - Every definition in this file must be tagged `@[simp]`, or the frozen
     proof cannot unfold it and the build fails (a reject, never unsound).
   - Only `import Dsl`. -/

import Dsl

namespace Ratchet.Impl

open Ratchet (Circuit)

@[simp] def aIn  (i : Nat) : Circuit := .input i
@[simp] def bIn  (i : Nat) : Circuit := .input (8 + i)
@[simp] def opIn (i : Nat) : Circuit := .input (16 + i)

/- Structural restructure: the subtractor is GONE. One shared adder computes
   a + (b ^ isSub) + isSub, since a - b = a + (not b) + 1. The arithmetic
   side of the mux tree collapses to a single leg.
   op 00 = add, 01 = sub, 10 = and, 11 = xor. -/

@[simp] def isSub : Circuit := opIn 0

@[simp] def bEff (i : Nat) : Circuit := .xor (bIn i) isSub

@[simp] def carry : Nat → Circuit
  | 0     => isSub
  | i + 1 => .or (.and (aIn i) (bEff i))
                 (.and (carry i) (.xor (aIn i) (bEff i)))

@[simp] def arithBit (i : Nat) : Circuit := .xor (.xor (aIn i) (bEff i)) (carry i)

@[simp] def andBit (i : Nat) : Circuit := .and (aIn i) (bIn i)
@[simp] def xorBit (i : Nat) : Circuit := .xor (aIn i) (bIn i)

/-- s = true selects x. -/
@[simp] def mux (s x y : Circuit) : Circuit := .or (.and s x) (.and (.not s) y)

@[simp] def out (i : Nat) : Circuit :=
  mux (opIn 1) (mux (opIn 0) (xorBit i) (andBit i))
               (arithBit i)

end Ratchet.Impl
