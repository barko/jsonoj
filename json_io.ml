type t = Json_type.t
open Json_type

(*** Parsing ***)

let check_string_is_utf8 s =
  let encoding =
    if String.length s < 4 then `UTF8
    else Json_lexer.detect_encoding s.[0] s.[1] s.[2] s.[3] in
  if encoding <> `UTF8 then
    json_error "Only UTF-8 encoding is supported" 

let filter_result x =
  Browse.assert_object_or_array x;
  x

let json_of_string 
    ?allow_comments
    ?allow_nan
    ?big_int_mode
    ?(recursive = false)
    s =
  check_string_is_utf8 s;
  let p = Json_lexer.make_param ?allow_comments ?allow_nan ?big_int_mode () in
  let j = 
    Json_parser.main 
      (Json_lexer.token p)
      (Lexing.from_string s)
  in
  if not recursive then filter_result j
  else j


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

let escape_json_string buf s =
  for i = 0 to String.length s - 1 do
    let c = String.unsafe_get s i in
    match c with 
      | '"'    -> Buffer.add_string buf "\\\""
      | '\t'   -> Buffer.add_string buf "\\t"
      | '\r'   -> Buffer.add_string buf "\\r"
      | '\b'   -> Buffer.add_string buf "\\b"
      | '\n'   -> Buffer.add_string buf "\\n"
      | '\012' -> Buffer.add_string buf "\\f"
      | '\\'   -> Buffer.add_string buf "\\\\"
   (* | '/'    -> "\\/" *) (* Forward slash can be escaped 
			      but doesn't have to *)
      | '\x00'..'\x1F' (* Control characters that must be escaped *)
      | '\x7F' (* DEL *) -> 
	  Printf.bprintf buf "\\u%04X" (int_of_char c)
      | _      -> 
	  (* Don't bother detecting or escaping multibyte chars *)
	  Buffer.add_char buf c
  done

let fquote_json_string fmt s =
  let buf = Buffer.create (String.length s) in
  escape_json_string buf s;
  Format.fprintf fmt "\"%s\"" (Buffer.contents buf)

let bquote_json_string buf s =
  Printf.bprintf buf "\"%a\"" escape_json_string s

module Fast =
struct
  open Printf
  open Buffer

  (* Contiguous sequence of non-escaped characters are copied to the buffer
     using one call to Buffer.add_substring *)
  let rec buf_add_json_escstr1 buf s k1 l =
    if k1 < l then (
      let k2 = buf_add_json_escstr2 buf s k1 k1 l in
      if k2 > k1 then (
        let ssub = String.sub s k1 (k2 - k1) in
        Buffer.add_string buf ssub
	(* Buffer.add_substring buf s k1 (k2 - k1); *)
      );
      if k2 < l then (
	let c = String.unsafe_get s k2 in
	( match c with 
	    | '"'    -> Buffer.add_string buf "\\\""
	    | '\t'   -> Buffer.add_string buf "\\t"
	    | '\r'   -> Buffer.add_string buf "\\r"
	    | '\b'   -> Buffer.add_string buf "\\b"
	    | '\n'   -> Buffer.add_string buf "\\n"
	    | '\012' -> Buffer.add_string buf "\\f"
	    | '\\'   -> Buffer.add_string buf "\\\\"
	 (* | '/'    -> "\\/" *) (* Forward slash can be escaped 
				    but doesn't have to *)
	    | '\x00'..'\x1F' (* Control characters that must be escaped *)
	    | '\x7F' (* DEL *) -> 
		        Printf.bprintf buf "\\u%04X" (int_of_char c)
	    | _      -> assert false
	);
	buf_add_json_escstr1 buf s (k2+1) l
      )
    )

  and buf_add_json_escstr2 buf s k1 k2 l =
    if k2 < l then (
      let c = String.unsafe_get s k2 in
      match c with
	| '"' | '\t' | '\r' | '\b' | '\n' | '\012' | '\\' (*| '/'*)
	| '\x00'..'\x1F' | '\x7F' -> k2
	| _ -> buf_add_json_escstr2 buf s k1 (k2+1) l
    )
    else
      l

  and bquote_json_string buf s =
    Buffer.add_char buf '"';
    buf_add_json_escstr1 buf s 0 (String.length s);
    Buffer.add_char buf '"'

  let rec bprint_json allow_nan buf = function
      Object o -> 
	add_string buf "{";
	bprint_object allow_nan buf o;
	add_string buf "}"
    | Array a -> 
	add_string buf "[";
	bprint_list allow_nan buf a;
	add_string buf "]"
    | Bool b -> 
	add_string buf (if b then "true" else "false")
    | Null -> 
	add_string buf "null"
    | Int i -> add_string buf (string_of_int i)
    | Float f -> add_string buf (string_of_json_float allow_nan f)
    | String s -> bquote_json_string buf s
	
  and bprint_list allow_nan buf = function
      [] -> ()
    | [x] -> bprint_json allow_nan buf x
    | x :: tl -> 
	bprint_json allow_nan buf x;
	add_string buf ","; 
	bprint_list allow_nan buf tl
	  
  and bprint_object allow_nan buf = function
      [] -> ()
    | [x] -> bprint_pair allow_nan buf x
    | x :: tl -> 
	bprint_pair allow_nan buf x;
	add_string buf ","; 
	bprint_object allow_nan buf tl

  and bprint_pair allow_nan buf (key, x) =
    bquote_json_string buf key;
    bprintf buf ":";
    bprint_json allow_nan buf x

  (* json does not allow rendering floats with a trailing dot: that is,
     1234. is not allowed, but 1234.0 is ok.  here, we add a '0' if
     string_of_int result in a trailing dot *)
  and string_of_json_float allow_nan f =
    match classify_float f with
	FP_nan -> 
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

  let print ?(allow_nan = false) ?(recursive = false) buf x =
    if not recursive then
      Browse.assert_object_or_array x;
    bprint_json allow_nan buf x
end

let string_of_json ?allow_nan ?recursive x =
  let buf = Buffer.create 2000 in
  Fast.print ?allow_nan ?recursive buf x;
  Buffer.contents buf

