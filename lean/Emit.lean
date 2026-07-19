/- FROZEN. Run by score.sh: `lake env lean Emit.lean` (from lean/).
   Writes build/alu.v. The input naming here must match Equiv.env:
   inputs 0-7 = a[0..7], inputs 8-15 = b[0..7]. Trusted seam. -/

import Impl.Alu

open Ratchet

def nameOf (i : Nat) : String :=
  if i < 8 then s!"a[{i}]" else s!"b[{i - 8}]"

#eval do
  let assigns := (List.range 8).map fun i =>
    s!"  assign y[{i}] = {(Impl.out i).toV nameOf};"
  let text := String.intercalate "\n" <|
    [ "module alu("
    , "  input  [7:0] a,"
    , "  input  [7:0] b,"
    , "  output [7:0] y"
    , ");" ]
    ++ assigns
    ++ [ "endmodule", "" ]
  IO.FS.writeFile "build/alu.v" text
