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

/- Seed: a deliberately naive ripple-carry adder. XOR is expanded into
   AND/OR/NOT, and the carry is a three-product majority. Headroom on purpose. -/

@[simp] def xr (x y : Circuit) : Circuit := .and (.or x y) (.not (.and x y))

@[simp] def carry : Nat → Circuit
  | 0     => .const false
  | i + 1 => .or (.or (.and (aIn i) (bIn i)) (.and (aIn i) (carry i)))
                 (.and (bIn i) (carry i))

@[simp] def out (i : Nat) : Circuit := xr (xr (aIn i) (bIn i)) (carry i)

end Ratchet.Impl
