/- FROZEN. The specification. Ground truth; the loop never touches this. -/

namespace Ratchet.Spec

/-- 8-bit ALU. op: 00 = add, 01 = sub, 10 = and, 11 = xor. -/
def alu (op : BitVec 2) (a b : BitVec 8) : BitVec 8 :=
  if op = 0#2 then a + b
  else if op = 1#2 then a - b
  else if op = 2#2 then a &&& b
  else a ^^^ b

end Ratchet.Spec
