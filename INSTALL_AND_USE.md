gen_js_api: installation and usage instructions
===============================================


Dependencies
------------

gen_js_api does not have any external build-time dependency except
the OCaml compiler (version 4.03).  Of course, it will be used
in conjuncion with the js_of_ocaml compiler and runtime support.


Installation (with OPAM)
------------------------

````
opam install gen_js_api
````

Or, to track the development version:

````
opam pin add gen_js_api https://github.com/LexiFi/gen_js_api.git
````

Manual installation
-------------------

````
git clone https://github.com/LexiFi/gen_js_api.git
cd gen_js_api
make all
make install  # assuming ocamlfind is installed
````


Usage (with ocamlfind)
----------------------

 - Invoking the [standalone tool](IMPLGEN.md) (`.mli` -> `.ml` generator):

   ```
   ocamlfind gen_js_api/gen_js_api my_unit.mli
   ```

 - Compiling binding (`.mli` and generated `.ml` files) and user
   code which rely on the `Ojs` module:

   ```
   ocamlfind ocamlc -package gen_js_api my_unit.mli
   ocamlfind ocamlc -package gen_js_api my_unit.ml
   ```

 - Compiling with the [ppx processor](PPX.md):

   ```
   ocamlfind ocamlc -c -package gen_js_api.ppx my_prog.ml
   ```

 - Linking the bytecode program:

   ```
   ocamlfind ocamlc -o my_prog -no-check-prims -package gen_js_api -linkpkg ...
   ```

 - Compiling into Javascript:

   ```
   js_of_ocaml -o my_prog.js +gen_js_api/ojs_runtime.js my_prog
   ```
