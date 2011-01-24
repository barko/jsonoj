(** Pseudo-compatibility with other JSON implementation.
  Do not use this module in new programs. *)

type jsontype = Json_type.t

(** @deprecated 
  Use {!Json_io.string_of_json} instead. *)
let serialize x = Json_io.string_of_json x

(** @deprecated 
  Use {!Json_io.json_of_string} instead. *)
let deserialize s = Json_io.json_of_string ~allow_comments:true s
