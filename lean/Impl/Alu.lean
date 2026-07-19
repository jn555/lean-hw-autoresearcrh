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

/- Seed: four fully independent datapaths (ripple adder, ripple subtractor,
   and-array, xor-array) and a gate-level mux tree per output bit.
   op 00 = add, 01 = sub, 10 = and, 11 = xor. Naive on purpose. -/

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
@[simp] def xorBit (i : Nat) : Circuit := .xor (aIn i) (bIn i)

/-- s = true selects x. -/
@[simp] def mux (s x y : Circuit) : Circuit := .or (.and s x) (.and (.not s) y)

@[simp] def out (i : Nat) : Circuit :=
  mux (opIn 1) (mux (opIn 0) (xorBit i) (andBit i))
               (mux (opIn 0) (subBit i) (addBit i))

end Ratchet.Impl
