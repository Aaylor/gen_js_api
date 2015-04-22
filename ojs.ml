(* The gen_js_api is released under the terms of an MIT-like license.     *)
(* See the attached LICENSE file.                                         *)
(* Copyright 2015 by LexiFi.                                              *)

(* This module (mostly) abstracts away from js_of_ocaml encoding of
   OCaml values.  It serves as a support library for the code generated
   by gen_js_api.

   The module could mostly be implemented on top of js_of_ocaml's Js module
   (and in particular Js.Unsafe), but we prefer to drop the dependency
   to js_of_ocaml's library and to rely only on its compiler and JS
   runtime code.
*)


type t

external t_of_js: t -> t = "%identity"
external t_to_js: t -> t = "%identity"

external string_of_js: t -> string = "caml_js_to_string"
external string_to_js: string -> t = "caml_js_from_string"

external int_of_js: t -> int = "%identity"
external int_to_js: int -> t = "%identity"

external bool_of_js: t -> bool = "caml_js_to_bool"
external bool_to_js: bool -> t = "caml_js_from_bool"

external float_of_js: t -> float = "%identity"
external float_to_js: float -> t = "%identity"

external obj: (string * t) array -> t = "caml_js_object"

external variable: string -> t = "caml_js_var"

external internal_get: t -> t -> t = "caml_js_get"
external internal_set: t -> t -> t -> unit = "caml_js_set"

let get x name = internal_get x (string_to_js name)
let set x name y = internal_set x (string_to_js name) y

external internal_type_of: t -> t = "caml_js_typeof"
let type_of x = string_of_js (internal_type_of x)

external pure_js_expr: string -> t = "caml_pure_js_expr"
let null = pure_js_expr "null"
let undefined = pure_js_expr "undefined"

external equals: t -> t -> bool = "caml_js_equals"

let global = variable "joo_global_object"

external internal_new_obj: t -> t array -> t = "caml_js_new"
let new_obj name args =
  let constr = get global name in
  internal_new_obj constr args

external call: t -> string -> t array -> t = "caml_js_meth_call"
let call_unit o s args = ignore (call o s args)

external apply: t -> t array -> t = "caml_js_fun_call"
let apply_unit f x = ignore (apply f x)

let array_make n = new_obj "Array" [|int_to_js n|]
let array_get t i = internal_get t (int_to_js i)
let array_set t i x = internal_set t (int_to_js i) x

let array_of_js f objs =
  Array.init
    (int_of_js (get objs "length"))
    (fun i -> f (array_get objs i))

let array_to_js f arr =
  let n = Array.length arr in
  let a = array_make n in
  for i = 0 to n - 1 do
    array_set a i (f arr.(i))
  done;
  a

let list_of_js f objs =
  Array.to_list (array_of_js f objs)

let list_to_js f l =
  array_to_js f (Array.of_list l)

let option_of_js f x =
  if equals x null || x == undefined then None
  else Some (f x)

let option_to_js f = function
  | Some x -> f x
  | None -> null

class obj (x:t) =
  object
    method to_js = x
  end

external internal_eval: string -> t = "caml_js_eval_string"
let () = set global "caml_js_wrapfun" (internal_eval "(function (f) { return function() { return f(Array.prototype.slice.call(arguments)); }; })")

let fun_to_js (f:t->t) : t = apply (variable "caml_js_wrapfun") [|Obj.magic f|]
let fun_unit_to_js (f:t->unit) : t = apply (variable "caml_js_wrapfun") [|Obj.magic f|]
(* external fun_to_js: ('a -> 'b) -> t = "caml_js_wrap_callback" *)
