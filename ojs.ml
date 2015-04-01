(***************************************************************************)
(*  Copyright (C) 2000-2015 LexiFi SAS. All rights reserved.               *)
(*                                                                         *)
(*  No part of this document may be reproduced or transmitted in any       *)
(*  form or for any purpose without the express permission of LexiFi SAS.  *)
(***************************************************************************)

(* $Id: ojs.ml 80187 2015-03-27 16:40:57Z afrisch $ *)

type t = Js.Unsafe.any

let to_string o = Js.to_string (Obj.magic o)
let of_string s = Js.Unsafe.inject (Js.string s)

let of_int = Js.Unsafe.inject
let to_int = Obj.magic

let of_fun f = Js.Unsafe.inject (Js.wrap_callback f)
let of_unit_fun f = Js.Unsafe.inject (Js.wrap_callback f)

let call = Js.Unsafe.meth_call
let call_unit o s args = ignore (call o s args)

let apply f x = Js.Unsafe.fun_call f x
let apply_unit f x = ignore (apply f x)

let get = Js.Unsafe.get
let set = Js.Unsafe.set

let obj = Js.Unsafe.obj


let array_get t i = Obj.magic (Js.array_get (Obj.magic t) i)

let to_array f objs =
  Array.init
    (to_int (get objs "length"))
    (fun i -> f (array_get objs i))

let of_array _f _arr =
  assert false

let variable = Js.Unsafe.variable
