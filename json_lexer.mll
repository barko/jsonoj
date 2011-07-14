{
  open Printf
  open Lexing

  open Json_type
  open Json_parser

  let loc lexbuf = (lexbuf.lex_start_p, lexbuf.lex_curr_p)

  (* Detection of the encoding from the 4 first characters of the data *)
  let detect_encoding c1 c2 c3 c4 =
    match c1, c2, c3, c4 with
      | '\000', '\000', '\000', _      -> `UTF32BE 
      | '\000', _     , '\000', _      -> `UTF16BE
      | _     , '\000', '\000', '\000' -> `UTF32LE 
      | _     , '\000', _     , '\000' -> `UTF16LE 
      | _                              -> `UTF8

  let hexval c =
    match c with
	'0'..'9' -> int_of_char c - int_of_char '0'
      | 'a'..'f' -> int_of_char c - int_of_char 'a' + 10
      | 'A'..'F' -> int_of_char c - int_of_char 'A' + 10
      | _ -> assert false

  let make_int big_int_mode s =
    try INT (int_of_string s)
    with _ -> 
      if big_int_mode then STRING s
      else json_error (s ^ " is too large for OCaml's type int, sorry")

  (* taken from js_of_ocaml's deriving_Json_lexer.mll *)
  let utf8_of_bytes buf a b c d =
    let i = (a lsl 12) lor (b lsl 8) lor (c lsl 4) lor d in
    if i < 0x80 then
      Buffer.add_char buf (Char.chr i)
    else if i < 0x800 then begin
      Buffer.add_char buf (Char.chr (0xc0 lor ((i lsr 6) land 0x1f)));
      Buffer.add_char buf (Char.chr (0x80 lor (i land 0x3f)))
    end else (* i < 0x10000 *) begin
      Buffer.add_char buf (Char.chr (0xe0 lor ((i lsr 12) land 0xf)));
      Buffer.add_char buf (Char.chr (0x80 lor ((i lsr 6) land 0x3f)));
      Buffer.add_char buf (Char.chr (0x80 lor (i land 0x3f)))
    end

  let custom_error descr lexbuf =
    json_error 
      (sprintf "%s:\n%s"
	 (string_of_loc (loc lexbuf))
         descr)

  let lexer_error descr lexbuf =
    custom_error 
      (sprintf "%s '%s'" descr (Lexing.lexeme lexbuf))
      lexbuf

  let set_file_name lexbuf name =
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = name }

  let newline lexbuf =
    let pos = lexbuf.lex_curr_p in
    lexbuf.lex_curr_p <- { pos with
			     pos_lnum = pos.pos_lnum + 1;
			     pos_bol = pos.pos_cnum }

  type param = {
    allow_comments : bool;
    big_int_mode : bool;
    allow_nan : bool
  }
}

let space = [' ' '\t' '\r']+

let digit = ['0'-'9']
let nonzero = ['1'-'9']
let digits = digit+
let frac = '.' digits
let e = ['e' 'E']['+' '-']?
let exp = e digits

let int = '-'? (digit | nonzero digits)
let float = int frac | int exp | int frac exp

let hex = [ '0'-'9' 'a'-'f' 'A'-'F' ]

let unescaped = ['\x20'-'\x21' '\x23'-'\x5B' '\x5D'-'\xFF' ]

rule token p = parse
  | "//"[^'\n']* { 
      if p.allow_comments then 
	token p lexbuf
      else 
        lexer_error "Comments are not allowed: " lexbuf 
    }
  | "/*" { 
      if p.allow_comments then (
        comment lexbuf; 
	token p lexbuf
      )
      else 
        lexer_error "Comments are not allowed: " lexbuf 
    }
  | '{'     { OBJSTART }
  | '}'     { OBJEND }
  | '['     { ARSTART }
  | ']'     { AREND }
  | ','     { COMMA }
  | ':'     { COLON }
  | "true"  { BOOL true }
  | "false" { BOOL false }
  | "null"  { NULL }
  | "NaN"   { 
      if p.allow_nan then 
        FLOAT nan
      else 
        lexer_error "NaN values are not allowed: " lexbuf 
    }
  | "Infinity" { 
      if p.allow_nan then 
        FLOAT infinity
      else 
        lexer_error "Infinite values are not allowed: " lexbuf 
    }
  | "-Infinity" { 
      if p.allow_nan then 
        FLOAT neg_infinity
      else 
        lexer_error "Infinite values are not allowed: " lexbuf 
    }
  | '"' { 
      let l = ref [] in
      while string l lexbuf do () done;
      STRING (String.concat "" (List.rev !l)) 
    }
  | int     { make_int p.big_int_mode (lexeme lexbuf) }
  | float   { FLOAT (float_of_string (lexeme lexbuf)) }
  | "\n"    { newline lexbuf; token p lexbuf }
  | space   { token p lexbuf }
  | eof     { EOF }
  | _       { lexer_error "Invalid token" lexbuf }


and string l = parse
    '"'         { false }
  | '\\'        { let s = escaped_char lexbuf in l := s :: !l; true }
  | unescaped+  { let s = lexeme lexbuf in l := s :: !l; true }
  | _ as c      { custom_error 
		    (sprintf "Unescaped control character \\u%04X or \
                              unterminated string" (int_of_char c))
		    lexbuf }
  | eof         { custom_error "Unterminated string" lexbuf }


and escaped_char = parse 
  | '"'
  | '\\'
  | '/'  { lexeme lexbuf }
  | 'b'  { "\b" }
  | 'f'  { "\012" }
  | 'n'  { "\n" }
  | 'r'  { "\r" }
  | 't'  { "\t" }
  | 'u' (hex as a) (hex as b) (hex as c) (hex as d) { 
      let buf = Buffer.create 5 in
      utf8_of_bytes buf (Char.code a) (Char.code b) (Char.code c) (Char.code d);
      Buffer.contents buf
    }
  | _  { lexer_error "Invalid escape sequence" lexbuf }

and comment = parse
  | "*/" { () }
  | eof  { lexer_error "Unterminated comment" lexbuf }
  | '\n' { newline lexbuf; comment lexbuf }
  | _    { comment lexbuf }

{
  let make_param 
      ?(allow_comments = false)
      ?(allow_nan = false)
      ?(big_int_mode = false)
      () =
    { allow_comments = allow_comments;
      big_int_mode = big_int_mode;
      allow_nan = allow_nan }
}
