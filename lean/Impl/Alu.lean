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

/- Generate/propagate carry chain: carry = (a & b) | ((a | b) & c) — the
   or-propagate is valid for the carry; the sum keeps its own a ^ b. -/

@[simp] def carry : Nat → Circuit
  | 0     => .const false
  | i + 1 => .or (.and (aIn i) (bIn i))
                 (.and (.or (aIn i) (bIn i)) (carry i))

@[simp] def out (i : Nat) : Circuit := .xor (.xor (aIn i) (bIn i)) (carry i)

end Ratchet.Impl
