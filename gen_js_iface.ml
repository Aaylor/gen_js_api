(***************************************************************************)
(*  Copyright (C) 2000-2015 LexiFi SAS. All rights reserved.               *)
(*                                                                         *)
(*  No part of this document may be reproduced or transmitted in any       *)
(*  form or for any purpose without the express permission of LexiFi SAS.  *)
(***************************************************************************)

(* $Id: gen_js_iface.ml 80189 2015-03-27 17:18:29Z afrisch $ *)

open Location
open Asttypes
open Parsetree
open Longident
open Ast_helper

(** Errors *)

type error =
  | Expression_expected
  | Identifier_expected
  | Invalid_expression
  | Multiple_binding_declarations
  | Binding_type_mismatch

exception Error of Location.t * error

let error loc err = raise (Error (loc, err))

let print_error ppf = function
  | Expression_expected ->
      Format.fprintf ppf "Expression expected"
  | Identifier_expected ->
      Format.fprintf ppf "String literal expected"
  | Invalid_expression ->
      Format.fprintf ppf "Invalid expression"
  | Multiple_binding_declarations ->
      Format.fprintf ppf "Multiple binding declarations"
  | Binding_type_mismatch ->
      Format.fprintf ppf "Binding declaration and type are not compatible"

let () =
  Location.register_error_of_exn
    (function
      | Error (loc, err) -> Some (Location.error_of_printer loc print_error err)
      | _ -> None
    )


(** AST *)

type typ =
  | String
  | Int
  | Arrow of typ list * typ
  | Array of typ
  | Unit
  | Js
  | Name of string

type expr =
  | Id of string
  | Str of string
  | Call of expr * expr list

type valdef =
  | Cast
  | PropGet of string
  | PropSet of string
  | MethCall of string
  | Global of string
  | Expr of expr

type decl =
  | Module of string * decl list
  | JsType of string
  | Val of string * typ * valdef * Location.t

(** Parsing *)

let rec parse_expr e =
  match e.pexp_desc with
  | Pexp_ident {txt=Lident s} -> Id s
  | Pexp_constant (Const_string (s, _)) -> Str s
  | Pexp_apply (e, args) ->
      Call
        (parse_expr e,
         List.map
           (function
             | (Nolabel, e) -> parse_expr e
             | _ -> error e.pexp_loc Invalid_expression
           )
           args
        )
  | _ ->
     error e.pexp_loc Invalid_expression

let rec parse_typ ty =
  match ty.ptyp_desc with
  | Ptyp_arrow (_, t1, t2) ->
      let t1 = parse_typ t1 in
      begin match parse_typ t2 with
      | Arrow (tl, t2) -> Arrow (t1 :: tl, t2)
      | t2 -> Arrow ([t1], t2)
      end
  | Ptyp_constr ({txt = Lident "array"}, [t1]) ->
      Array (parse_typ t1)
  | Ptyp_constr ({txt = lid}, []) ->
      begin match String.concat "." (Longident.flatten lid) with
      | "string" -> String
      | "int" -> Int
      | "unit" -> Unit
      | "Ojs.t" -> Js
      | s -> Name s
      end
  | _ ->
      Format.printf "%aCannot parse this type.@."
        Location.print_error ty.ptyp_loc;
      exit 2

let check_prefix ~prefix s =
  let l = String.length prefix in
  if l <= String.length s && String.sub s 0 l = prefix
  then
    Some (String.sub s l (String.length s - l))
  else
    None

let has_prefix ~prefix s = check_prefix ~prefix s <> None
let drop_prefix ~prefix s =
  match check_prefix ~prefix s with
  | Some x -> x
  | None -> assert false

let auto loc s ty =
  match ty with
  | Arrow ([Name _], _) ->
      PropGet s

  | Arrow ([Name _; _], Unit)
    when has_prefix ~prefix:"set_" s ->
      PropSet (drop_prefix ~prefix:"set_" s)

  | Arrow (Name _ :: _, _) ->
      MethCall s

  | _ ->
      Global s

let id_of_expr = function
  | {pexp_desc=Pexp_constant (Const_string (s, _)); _}
  | {pexp_desc=Pexp_ident {txt=Lident s;_}; _}
  | {pexp_desc=Pexp_construct ({txt=Lident s;_}, None); _} -> s
  | e -> error e.pexp_loc Identifier_expected

let expr_of_stritem = function
  | {pstr_desc=Pstr_eval (e, _); _} -> e
  | p -> error p.pstr_loc Expression_expected

let expr_of_payload loc = function
  | PStr [x] -> expr_of_stritem x
  | _ -> error loc Expression_expected

let parse_valdecl loc s ty attrs =
  let parse_attr defs (k, v) =
    let opt_name () =
      match v with
      | PStr [] -> s (* default *)
      | e -> id_of_expr (expr_of_payload k.loc e)
    in
    match k.txt, v with
    | "js.cast", _ ->
        Cast :: defs
    | "js.expr", e ->
        Expr (parse_expr (expr_of_payload k.loc e)) :: defs
    | "js.get", _ ->
        PropGet (opt_name ()) :: defs
    | "js.set", _ ->
        PropSet (opt_name ()) :: defs
    | "js.meth", _ ->
        MethCall (opt_name ()) :: defs
    | "js.global", _ ->
        Global (opt_name ()) :: defs
    | _ ->
        defs
  in
  let defs = List.fold_left parse_attr [] attrs in
  match defs with
  | [x] -> x
  | [] -> auto loc s ty
  | _ ->
      error loc Multiple_binding_declarations

let rec parse_sig_item s =
  match s.psig_desc with
  | Psig_value {pval_prim = []; pval_name; pval_type; pval_attributes; pval_loc; _} ->
      let name = pval_name.txt in
      let ty = parse_typ pval_type in
      Val (name, ty,
           parse_valdecl pval_loc name ty pval_attributes,
           pval_loc
          )
  | Psig_type (_,
               [ {ptype_name; ptype_params = [];
                  ptype_cstrs = [];
                  ptype_kind = Ptype_abstract;
                  ptype_private = Private;
                  ptype_manifest = Some ty;
                  _}
               ]) when parse_typ ty = Js ->
      JsType ptype_name.txt
  | Psig_module {pmd_name; pmd_type = {pmty_desc = Pmty_signature si; _}; _} ->
      Module (pmd_name.txt, parse_sig si)
  | _ ->
      Format.printf "%aCannot parse this signature item.@."
        Location.print_error s.psig_loc;
      exit 2

and parse_sig s =
  List.map parse_sig_item s

(** Code generation *)

let ojs s =  mknoloc (Ldot (Lident "Ojs", s))
let var x = Exp.ident (mknoloc (Lident x))
let app f args = Exp.apply f (List.map (fun e -> (Nolabel, e)) args)
let str s = Exp.constant (Const_string (s, None))
let fun_ s e = Exp.fun_ Nolabel None (Pat.var (mknoloc s)) e
let fun_unit e = Exp.fun_ Nolabel None (Pat.construct (mknoloc (Lident "()")) None) e

let func = List.fold_right (fun s rest -> fun_ s rest)



let def s ty body =
  Str.value Nonrecursive [ Vb.mk (Pat.constraint_ (Pat.var (mknoloc s)) ty) body ]

let rec js2ml ty exp =
  match ty with
  | String ->
      app (Exp.ident (ojs "to_string")) [exp]
  | Int ->
      app (Exp.ident (ojs "to_int")) [exp]
  | Js ->
      exp
  | Name s ->
      app (Exp.ident (mknoloc (Longident.parse (s ^ "_of_js")))) [exp]
  | Array ty ->
      app
        (Exp.ident (ojs "to_array"))
        [
          fun_ "elt" (js2ml ty (var "elt"));
          exp
        ]
  | _ ->
      assert false
(*
      Exp.extension (mknoloc "unknown", PStr [])
*)

and ml2js ty exp =
  match ty with
  | String ->
      app (Exp.ident (ojs "of_string")) [exp]
  | Int ->
      app (Exp.ident (ojs "of_int")) [exp]
  | Js ->
      exp
  | Name s ->
      app (Exp.ident (mknoloc (Longident.parse (s ^ "_to_js")))) [exp]
  | Arrow ([Unit], Unit) ->
      app (Exp.ident (ojs "of_unit_fun")) [exp]
(*
      Exp.coerce exp (Some (gen_typ ty)) (gen_typ Js)
*)
  | _ ->
      assert false
(*
      Exp.extension (mknoloc "unknown", PStr [])
*)

and gen_typ = function
  | String ->
      Typ.constr (mknoloc (Lident "string")) []
  | Int ->
      Typ.constr (mknoloc (Lident "int")) []
  | Name s ->
      Typ.constr (mknoloc (Longident.parse s)) []
  | Js ->
      Typ.constr (mknoloc (Longident.parse "Ojs.t")) []
  | Unit ->
      Typ.constr (mknoloc (Lident "unit")) []
  | Arrow (tl, t2) ->
      List.fold_right
        (fun t1 t2 -> Typ.arrow Nolabel (gen_typ t1) t2)
        tl
        (gen_typ t2)
  | Array ty ->
      Typ.constr (mknoloc (Lident "array")) [gen_typ ty]

let gen_args ty_args =
  List.mapi
    (fun i ty ->
       let s = Printf.sprintf "arg%i" i in
       s, ml2js ty (var s)
    )
    ty_args

let map_res res ty_res =
  match ty_res with
  | Unit -> res
  | _ -> js2ml ty_res res

let map_args = function
  | [Unit] -> []
  | args -> args

let rec gen_decls env si =
  List.concat (List.map (gen_decl env) si)

and gen_decl env = function
  | JsType t ->
      let lid = ojs "t" in
      [
        Str.type_ Recursive [ Type.mk (mknoloc t) ~manifest:(Typ.constr lid []) ];
        def (t ^ "_of_js") (gen_typ (Arrow ([Js], Name t))) (fun_ "this" (var "this"));
        def (t ^ "_to_js") (gen_typ (Arrow ([Name t], Js))) (fun_ "this" (var "this"));
      ]
  | Module (s, decls) ->
      [ Str.module_ (Mb.mk (mknoloc s) (Mod.structure (gen_decls env decls))) ]

  | Val (s, ty, decl, loc) ->
      let d = gen_def loc decl ty in
      [ def s (gen_typ ty) d ]

and gen_def loc decl ty =
  match decl, ty with
  | Cast, Arrow ([Name _ as ty_arg], (Name _ as ty_res)) ->
      fun_ "this" (js2ml ty_res (ml2js ty_arg (var "this")))

  | PropGet s, Arrow ([ty_this], ty_res) ->
      let res = app (Exp.ident (ojs "get")) [ml2js ty_this (var "this"); str s] in
      fun_ "this" (js2ml ty_res res)

  | PropSet s, Arrow ([Name _ as ty_this; ty_arg], Unit) ->
      let res =
        app (Exp.ident (ojs "set"))
          [
            ml2js ty_this (var "this");
            str s;
            ml2js ty_arg (var "arg")
          ]
      in
      fun_ "this" (fun_ "arg" res)

  | MethCall s, Arrow (ty_this :: ty_args, ty_res) ->
      let ty_args = map_args ty_args in
      let args = gen_args ty_args in
      let res =
        app
          (Exp.ident (ojs (if ty_res = Unit then "call_unit" else "call")))
          [
            ml2js ty_this (var "this");
            str s;
            Exp.array (List.map snd args)
          ]
      in
      let res = map_res res ty_res in
      fun_ "this"
        ((if args = [] then fun_unit else func (List.map fst args)) res)

  | Global s, Arrow (ty_args, ty_res) ->
      let ty_args = map_args ty_args in
      let args = gen_args ty_args in
      let res =
        app (Exp.ident (ojs (if ty_res=Unit then "apply_unit" else "apply")))
          [
            app (Exp.ident (ojs "variable")) [str s];
            Exp.array (List.map snd args)
          ]
      in
      let res = map_res res ty_res in
      (if ty_args = [] then fun_unit else func (List.map fst args)) res

  | Global s, ty_res ->
      let res = app (Exp.ident (ojs "variable")) [str s] in
      js2ml ty_res res

  | Expr e, Arrow (ty_args, ty_res) ->
      let ty_args = map_args ty_args in
      let args = gen_args ty_args in
      let res = map_res (gen_expr args e) ty_res in
      (if ty_args = [] then fun_unit else func (List.map fst args)) res

  | Expr e, ty ->
      js2ml ty (gen_expr [] e)

  | _ ->
      error loc Binding_type_mismatch

and gen_expr ids = function
  | Call (Id "call", obj :: Str meth :: args) ->
      app (Exp.ident (ojs "call"))
        [
          gen_expr ids obj;
          str meth;
          Exp.array (List.map (gen_expr ids) args)
        ]
  | Call (Id "global", [Str s]) ->
      app (Exp.ident (ojs "variable")) [str s]
  | Str s ->
      ml2js String (str s)
  | Id s when List.mem_assoc s ids ->
      List.assoc s ids
  | _ ->
      assert false
(*
      Exp.extension (mknoloc "unknown", PStr [])
*)

(** Main *)


let main () =
  let ocaml_ast =
    Pparse.parse_interface Format.err_formatter
      ~tool_name:"gen_js_iface"
      Sys.argv.(1)
  in
  let decls = parse_sig ocaml_ast in
  let str_ast = gen_decls () decls in
  Format.printf "%a@." Pprintast.structure str_ast


let () =
  try main ()
  with exn ->
    Format.eprintf "%a@." Location.report_exception exn;
    exit 2
