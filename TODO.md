TODO list for gen_js_api
========================



- Support sum types / polymorphic variants with non constant constructors
  (mapped to objects with a discriminator field).


- Support really abstract types (treated as `Ojs.t` in the implementation).

- Optimize generated code (for instance, lift calls to string_of_js on
  literals).

- Compile properly qualified globals [@@js.global "foo.bar"] to avoid
  js_of_ocaml warning.

- Add a notion of "object builder", i.e. a function with labeled or
  optional arguments which return an object initialized with the
  fields correponding to labels:


   ```ocaml
   type t = private Ojs.t
   val make: ?foo:int -> bar:string -> ?ty:(string[@js"type"]) -> unit -> t
     [@@js.builder]
   ```

  This would return a JS object with fields initialized as provided.
  Typical example:  the "settings" argument to jQuery's ajax function.
