/- THE ONLY FILE THE LOOP EDITS.

   Interface contract (the frozen proof depends on it):
   - `Ratchet.Impl.out : Nat → Circuit` must exist; `out i` is output bit i.
   - Input encoding: `.input 0`..`.input 7` are bits of `a` (LSB first),
     `.input 8`..`.input 15` are bits of `b`.
   - Every definition in this file must be tagged `@[simp]`, or the frozen
     proof cannot unfold it and the build fails (a reject, never unsound).
   - Only `import Dsl`. -/

import Dsl

namespace Ratchet.Impl

open Ratchet (Circuit)

@[simp] def aIn (i : Nat) : Circuit := .input i
@[simp] def bIn (i : Nat) : Circuit := .input (8 + i)

/- Generate/propagate form: g = a & b, p = a | b, carry = g | (p & c),
   sum = p ^ c. Reuses p for the half-sum to save the xor gates. -/

@[simp] def gen (i : Nat) : Circuit := .and (aIn i) (bIn i)
@[simp] def prp (i : Nat) : Circuit := .or (aIn i) (bIn i)

@[simp] def carry : Nat → Circuit
  | 0     => .const false
  | i + 1 => .or (gen i) (.and (prp i) (carry i))

@[simp] def out (i : Nat) : Circuit := .xor (prp i) (carry i)

end Ratchet.Impl
