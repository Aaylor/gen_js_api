open Test_js

let doc = Window.document window

let elt name ?(attrs = []) ?onclick subs =
  let e = Document.createElement doc name in
  List.iter (fun (k, v) -> Element.setAttribute e k v) attrs;
  List.iter (Element.appendChild e) subs;
  begin match onclick with
  | Some f -> Element.set_onclick e f
  | None -> ()
  end;
  e

let txt =
  Document.createTextNode doc

let button ?attrs s onclick =
  elt "button" ?attrs ~onclick [ txt s ]

let div = elt "div"

let () =
  Array.iter (Printf.printf "[%i]\n") myArray;


  Ojs.array_set myArray2 0 (Ojs.int_to_js 10);
  Ojs.array_set myArray2 1 (Ojs.array_to_js Ojs.int_to_js [| 100; 200; 300 |]);
(*  Ojs.array_set myArray2 1 ([%to_js: int array] [| 100; 200; 300 |]); *)

(*
  Printf.printf "%0.2f\n" 3.1415;
*)
(*
  Document.set_title doc "MyTitle";
  Document.set_title doc (Document.title doc ^ " :-)");
*)

(*  let main = Document.getElementById doc "main" in *)
(*  print_endline (Element.innerHTML main); *)
(*  alert (Element.innerHTML main); *)
(*  Element.set_innerHTML main "<b>Bla</b>blabla"; *)


  let draw () =
    let canvas_elt = Document.getElementById doc "canvas" in
    let canvas = Canvas.of_element canvas_elt in
    let ctx = Canvas.getContext_2d canvas in
    Canvas.RenderingContext2D.(begin
        set_fillStyle ctx "rgba(0,0,255,0.1)";
        fillRect ctx 30 30 50 50
      end);
    Element.set_onclick canvas_elt (fun () -> alert "XXX");
  in
  alert_bool true;
  alert_float 3.1415;
  let f =
    wrapper
      (fun x y ->
         Printf.printf "IN CALLBACK, x = %i, y = %i\n%!" x y;
         x + y
      )
  in
  Printf.printf "Result -> %i\n%!" (f 42 1);

  let uid = ref 0 in
  let f () =
    incr uid;
    Printf.printf "uid = %i\n%!" !uid;
    !uid
  in
  Printf.printf "Caller result -> %i, %i, %i\n%!" (caller f) (caller f) (caller f);
  caller_unit (fun () -> ignore (f ()));
  caller_unit (fun () -> ignore (f ()));
  caller_unit (fun () -> ignore (f ()));



  let body = Document.body doc in
  setTimeout (fun () -> Element.setAttribute body "bgcolor" "red") 2000;
  Element.appendChild body (Document.createTextNode doc "ABC");
  Element.appendChild body
    (div ~attrs:["style", "color: blue"] [ txt "!!!!"; elt "b" [txt "XXX"] ]);

  let l = Document.getElementsByClassName doc "myClass" in
  Array.iter
    (fun e ->
       Printf.printf "- [%s]\n" (Element.innerHTML e); (* OK *)
       print_string (Printf.sprintf "+ [%s]\n" (Element.innerHTML e)); (* BAD *)

       Element.appendChild e (button "Click!" draw);
       Element.appendChild e (button "XXX" (fun () -> ()));
    )
    l;
