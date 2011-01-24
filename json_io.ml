type t = Json_type.t
open Json_type

(*** Parsing ***)

let check_string_is_utf8 s =
  let encoding =
    if String.length s < 4 then `UTF8
    else Json_lexer.detect_encoding s.[0] s.[1] s.[2] s.[3] in
  if encoding <> `UTF8 then
    json_error "Only UTF-8 encoding is supported" 

let json_of_string 
    ?allow_comments
    ?allow_nan
    ?big_int_mode
    s =
  check_string_is_utf8 s;
  let p = Json_lexer.make_param ?allow_comments ?allow_nan ?big_int_mode () in
  let j = 
    Json_parser.main 
      (Json_lexer.token p)
      (Lexing.from_string s)
  in
  j


(*** Printing ***)

(* JSON does not allow rendering floats with a trailing dot: that is,
   1234. is not allowed, but 1234.0 is ok.  here, we add a '0' if
   string_of_int result in a trailing dot *)
let fprint_float allow_nan fmt f =
  match classify_float f with
      FP_nan -> 
	if allow_nan then Format.fprintf fmt "NaN"
	else json_error "Not allowed to serialize NaN value"
    | FP_infinite ->
	if allow_nan then
	  if f < 0. then Format.fprintf fmt "-Infinity"
	  else Format.fprintf fmt "Infinity"
	else json_error "Not allowed to serialize infinite value"
    | FP_zero
    | FP_normal
    | FP_subnormal ->
	let s = string_of_float f in
	Format.fprintf fmt "%s" s;
	let s_len = String.length s in
	if s.[ s_len - 1 ] = '.' then
	  Format.fprintf fmt "0"

let hex n =
  Char.chr (
    if n < 10 then 
      n + 48
    else 
      n + 87
  )

let escape_json_string add_string add_char s =
  for i = 0 to String.length s - 1 do
    let c = String.unsafe_get s i in
    match c with 
      | '"'    -> add_string "\\\""
      | '\t'   -> add_string "\\t"
      | '\r'   -> add_string "\\r"
      | '\b'   -> add_string "\\b"
      | '\n'   -> add_string "\\n"
      | '\012' -> add_string "\\f"
      | '\\'   -> add_string "\\\\"
   (* | '/'    -> "\\/" *) (* Forward slash can be escaped 
			      but doesn't have to *)
      | '\x00'..'\x1F' (* Control characters that must be escaped *)
      | '\x7F' (* DEL *) -> 

        add_string "\\u00";
        let code = Char.code c in
        add_char (hex (code lsr 4));
        add_char (hex (code land 0xf));

      | _  -> 
	(* Don't bother detecting or escaping multibyte chars *)
	add_char c
  done

(* Determine whether a string as any characters that would need to
   be escaped *)
let rec has_char_to_escape s len i =
  if i < len then (
    let c = String.unsafe_get s i in
    match c with
      | '"' | '\t' | '\r' | '\b' | '\n' | '\012' | '\\' (*| '/'*)
      | '\x00'..'\x1F' | '\x7F' -> true
      | _ -> has_char_to_escape s len (i+1)
  )
  else
    false

let has_char_to_escape s =
  has_char_to_escape s (String.length s) 0

let bquote_json_string buf s =
  Buffer.add_string buf "\"";

  (* avoid adding strings, which commonly contain no characters needing escape, 
     one character at-a-time.  *)
  if has_char_to_escape s then
    escape_json_string (Buffer.add_string buf) (Buffer.add_char buf) s
  else
    Buffer.add_string buf s;

  Buffer.add_string buf "\""

let rec bprint_json allow_nan buf = function
  | Object o -> 
    Buffer.add_string buf "{";
    bprint_object allow_nan buf o;
    Buffer.add_string buf "}"

  | Array a -> 
    Buffer.add_string buf "[";
    bprint_list allow_nan buf a;
    Buffer.add_string buf "]"

  | Bool b -> 
    Buffer.add_string buf (if b then "true" else "false")

  | Null -> 
    Buffer.add_string buf "null"

  | Int i -> 
    Buffer.add_string buf (string_of_int i)

  | Float f -> 
    Buffer.add_string buf (string_of_json_float allow_nan f)

  | String s -> 
    bquote_json_string buf s
      
and bprint_list allow_nan buf = function
  | [] -> ()
  | [x] -> bprint_json allow_nan buf x
  | x :: tl -> 
    bprint_json allow_nan buf x;
    Buffer.add_string buf ","; 
    bprint_list allow_nan buf tl
      
and bprint_object allow_nan buf = function
  | [] -> ()
  | [x] -> bprint_pair allow_nan buf x
  | x :: tl -> 
    bprint_pair allow_nan buf x;
    Buffer.add_string buf ","; 
    bprint_object allow_nan buf tl

and bprint_pair allow_nan buf (key, x) =
  bquote_json_string buf key;
  Buffer.add_string buf ":";
  bprint_json allow_nan buf x

(* json does not allow rendering floats with a trailing dot: that is,
   1234. is not allowed, but 1234.0 is ok.  here, we add a '0' if
   string_of_int result in a trailing dot *)
and string_of_json_float allow_nan f =
  match classify_float f with
    | FP_nan -> 
      if allow_nan then "NaN"
      else json_error "Not allowed to serialize NaN value"
    | FP_infinite ->
      if allow_nan then
	if f < 0. then "-Infinity"
	else "Infinity"
      else json_error "Not allowed to serialize infinite value"
    | FP_zero
    | FP_normal
    | FP_subnormal ->
      let s = string_of_float f in
      let s_len = String.length s in
      if s.[ s_len - 1 ] = '.' then
	s ^ "0"
      else
	s


let string_of_json ?(allow_nan=false) x =
  let buf = Buffer.create 2000 in
  bprint_json allow_nan buf x;
  Buffer.contents buf

