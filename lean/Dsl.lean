/- FROZEN. The circuit DSL: a deep-embedded combinational netlist over
   indexed input bits, its evaluation semantics, and the Verilog emitter.

   The emitter is trusted code: the proof is about `Circuit.eval`, the score
   is about the emitted Verilog. Keep both tiny and in one file so the seam
   stays auditable. -/

namespace Ratchet

inductive Circuit where
  | input (i : Nat)
  | const (b : Bool)
  | not   (x : Circuit)
  | and   (x y : Circuit)
  | or    (x y : Circuit)
  | xor   (x y : Circuit)

namespace Circuit

def eval (env : Nat → Bool) : Circuit → Bool
  | input i => env i
  | const b => b
  | not x   => !(eval env x)
  | and x y => eval env x && eval env y
  | or  x y => eval env x || eval env y
  | xor x y => Bool.xor (eval env x) (eval env y)

def toV (nameOf : Nat → String) : Circuit → String
  | input i => nameOf i
  | const b => if b then "1'b1" else "1'b0"
  | not x   => s!"(~{toV nameOf x})"
  | and x y => s!"({toV nameOf x} & {toV nameOf y})"
  | or  x y => s!"({toV nameOf x} | {toV nameOf y})"
  | xor x y => s!"({toV nameOf x} ^ {toV nameOf y})"

end Circuit
end Ratchet
