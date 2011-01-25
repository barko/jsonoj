(** Input and output functions for the JSON format 
  as defined by {{:http://www.json.org/}http://www.json.org/} *)


(** [json_of_string s] reads the given JSON string.

  If [allow_comments] is [true], then C++ style comments are allowed, i.e.
  [/* blabla possibly on several lines */] or 
  [// blabla until the end of the line]. Comments are not part of the JSON
  specification and are disabled by default.

  If [allow_nan] is [true], then OCaml [nan], [infinity] and [neg_infinity] 
  float values are represented using their Javascript counterparts
  [NaN], [Infinity] and [-Infinity].

  If [big_int_mode] is [true], then JSON ints that cannot be represented
  using OCaml's int type are represented by strings. 
  This would happen only for ints that are out of the range defined
  by [min_int] and [max_int], i.e. \[-1G, +1G\[ on a 32-bit platform.
  The default is [false] and a [Json_type.Json_error] exception
  is raised if an int is too big.

*)
val json_of_string : 
  ?allow_comments:bool ->
  ?allow_nan:bool ->
  ?big_int_mode:bool ->
  string -> Json_type.t

(** [string_of_json] converts JSON data to a string.

  By default, the output is indented. If the [compact] flag is set to true,
  the output will not contain superfluous whitespace and will
  be produced faster.

  If [allow_nan] is [true], then OCaml [nan], [infinity] and [neg_infinity] 
  float values are represented using their Javascript counterparts
  [NaN], [Infinity] and [-Infinity].
*)
val string_of_json :
  ?allow_nan: bool ->
  Json_type.t -> string


(** [escape_json_string add_string add_char s] returns an escaped json string.

    [add_string] and [add_char] are functions that write a string and char 
    to some destination 
*)
val escape_json_string : (string -> unit) -> (char -> unit) -> string -> unit

(** [string_of_json_float ~allow_nan f] stringifies [f] according to
    the JSON specificationsince [Pervasives.string_of_float] does not
    have the right properites. *)
val string_of_json_float : ?allow_nan:bool -> float -> string
