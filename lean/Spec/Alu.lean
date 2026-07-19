/- FROZEN. The specification. Ground truth; the loop never touches this. -/

namespace Ratchet.Spec

/-- 8-bit, 8-op ALU. op: 000 add, 001 sub, 010 and, 011 or, 100 xor,
    101 sltu (unsigned a < b), 110 slt (signed a < b), 111 nor. -/
def alu (op : BitVec 3) (a b : BitVec 8) : BitVec 8 :=
  if op = 0#3 then a + b
  else if op = 1#3 then a - b
  else if op = 2#3 then a &&& b
  else if op = 3#3 then a ||| b
  else if op = 4#3 then a ^^^ b
  else if op = 5#3 then (if a < b then 1#8 else 0#8)
  else if op = 6#3 then (if BitVec.slt a b then 1#8 else 0#8)
  else ~~~(a ||| b)

end Ratchet.Spec
