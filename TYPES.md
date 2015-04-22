Types supported in gen_js_api
=============================

JS-able types
-------------

A JS-able type is an OCaml type whose values can be mapped to and from
Javascript objects.  Technically, a non-parametrized type with path
`M.t` is JS-able if the following two values are available in module
`M`:

 ````
 val t_to_js: t -> Ojs.t
 val t_of_js: Ojs.t -> t
 ````

The name of these values is obtained by appending `_of_js` or `_to_js`
to the local name of the type.

Parametrized types can also be JS-able.  It is currently assumed that
such types are covariant in each of their parameter.  Mapping
functions take extra arguments corresponding to the mapper for each
parameter.  For instance, a type `'a t` would need to come with the following
functions:

 ````
 val t_to_js: ('a -> Ojs.t) -> 'a t -> Ojs.t
 val t_of_js: (Ojs.t -> 'a) -> Ojs.t -> 'a t
 ````

Some built-in types are treated in a special way to make them JS-able:
`string`, `int`, `bool`, `float`, `array`, `list`, `option`.  Arrays
and lists are mapped to JS arrays (which are assumed to be indexed by
integers 0..length-1).  Options are mapped to the same type as their
parameter: `None` is mapped to JS `null` value, and both `null` and
`undefined` are mapped back to `None`.  This encoding doesn't support
nested options in a faithful way.

JS-able type can be defined manually by defining `*_to_js` and
`*_of_js` functions.  They can also be created by gen_js_api
automatically when it processed type declarations.

The `Ojs.t` type itself is JS-able.

Arrow types can also be used in contexts that expect JS-able
types. The JS function's arity is obtained by counting arrows.  A
special case is when the OCaml arity is 1, with a single argument of
type unit, in which case the JS function is assumed to have no
argument.  In order to define functions that return functions, one can
put an arbitrary attribute on the resulting type:

   ```t1 -> (t2 -> t3 [@foo])```

Without the attribute, such a type would be parsed as a function of
arity 2 (returning type `t3`).


Variadic functions are supported, by adding a `[@js.variadic]`
attribute on the last parameter (which will represent all remaining
arguments):

  ````
    val sep: string -> (string list [@js.variadic]) -> string
  ````

The `unit` type can only be used in specific contexts: as the return
type of functions or methods, or as the unique argument.

Polymorphic types with only constant variants are supported.  See the section
on Enums below.


Type declarations
-----------------

All type declarations processed by gen_js_api create JS-able types,
i.e.  associated `*_to_js` and `*_to_js` mapping functions.  A
optional "private" modifier is allowed on the type declaration (in the
interface) and dropped from the generated definition (in the
implementation).  Mutually recursive type declarations are supported.


- "Abstract" subtype of `Ojs.t`:

    ````
    type t = private Ojs.t
    ````

  This is used to bind to JS "opaque" objects, with no runtime mapping
  involved when moving between OCaml and JS (mapping functions are the
  identity).

- Type abbreviation:

    ````
    type t = tyexp
    ````

  (formally, abstract types with a manifest).  This assumes that the
  abbreviated type expression is itself JS-able.  Note that the first
  kind of type declaration above (abstract subtypes of `Ojs.t`) are
  a special kind of such declaration, since `abstract` is always dropped
  and `Ojs.t` is JS-able.

- Record declaration:

    ````
    type t = { .... }
    ````

  This assumes that the type for all fields are JS-able.  Fields can
  be mutabled, but polymorphic fields are not yet supported.

  OCaml record values of this type are mapped to JS objects (one
  property per field).  By default, property names are equal to OCaml
  labels, but this can be changed manually with a `[@js]` attribute.

  ````
  type myType = { x : int; y : int [@js "Y"]}
  ````

- Sum type declaration, mapped to enums (see Enums section).


Enums
-----

Either polymorphic variants or normal sum types (all with constant
constructors) can be used to bind to "enums" in Javascript.  By
default, constructors are mapped to the JS string equal to their OCaml
name, but a custom translation can be provided with a `[@js]`
attribute.  This custom translation can be a string or an integer
literal.

    ````
    type t =
      | Foo [@js "foo"]
      | Bar [@js 42]
      | Baz

    type t = [`foo | `bar [@js 42] | `Baz]
    ````


It is possible to specify constructors with one argument of
type either int or string, used to represent "all other cases" of JS values.

  ````
    type status =
      | OK [@js 1]
      | KO [@js 2]
      | OtherS of string [@js.default]
      | OtherI of int [@js.default]
  ````

There cannot be two default constructors with the same argument type.
