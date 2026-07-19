/- FROZEN. The specification. Ground truth; the loop never touches this. -/

namespace Ratchet.Spec

/-- 8-bit addition, wrapping mod 2^8. -/
def alu (a b : BitVec 8) : BitVec 8 := a + b

end Ratchet.Spec
