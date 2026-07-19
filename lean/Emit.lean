/- FROZEN. Run by score.sh: `lake env lean Emit.lean` (from lean/).
   Writes build/alu.v. The input naming here must match Equiv.env:
   inputs 0-7 = a[0..7], 8-15 = b[0..7], 16-18 = op[0..2]. Trusted seam. -/

import Impl.Alu

open Ratchet

def nameOf (i : Nat) : String :=
  if i < 8 then s!"a[{i}]"
  else if i < 16 then s!"b[{i - 8}]"
  else s!"op[{i - 16}]"

#eval do
  let assigns := (List.range 8).map fun i =>
    s!"  assign y[{i}] = {(Impl.out i).toV nameOf};"
  let text := String.intercalate "\n" <|
    [ "module alu("
    , "  input  [7:0] a,"
    , "  input  [7:0] b,"
    , "  input  [2:0] op,"
    , "  output [7:0] y"
    , ");" ]
    ++ assigns
    ++ [ "endmodule", "" ]
  IO.FS.writeFile "build/alu.v" text
