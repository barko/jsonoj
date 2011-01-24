open Printf
open Arg
open Json_type
open Json_type.Build

let time title f arg =
  let t1 = Unix.gettimeofday () in
  let result = f arg in
  let t2 = Unix.gettimeofday () in
  printf "%s: %.3f s\n%!" title (t2 -. t1);
  result

let save_string file s =
  let oc = open_out file in
  output_string oc s;
  close_out oc

let save file data compact =
  time
    ("Saving file " ^ file)
    (fun () -> Json_io.save_json file ~compact data) ();
  time
    ("Saving file (using string) " ^ file)
    (fun () -> 
       save_string file (Json_io.string_of_json ~compact data)) ();
  if compact then
    (time
       "String conversion only"
       (fun () -> ignore (Json_io.string_of_json ~compact data)) ())

let load file =
  time
    ("Loading file " ^ file)
    Json_io.load_json file
    
let create_samples () =
  let deep = 
    Json_io.json_of_string 
      "[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[ \"Hi!\"
       ]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]" in
  let s = String.make 1_000_000 'x' in
  for i = 0 to 127 do
    s.[i] <- char_of_int i
  done;
  let x = 
    objekt [ "array", array (Array.to_list (Array.init 100_000 int));
	     "string", string s;
	     "int", int max_int;
	     "float", float 1e255;
	     "deep_array", array (Array.to_list (Array.make 1000 deep)) ] in
  save "sample-indented.json" x false;
  save "sample-compact.json" x true

let load_samples () =
  save "sample-indented2.json" (load "sample-indented.json") false;
  save "sample-compact2.json" (load "sample-compact.json") true

let test () =
  create_samples ();
  load_samples ()


let main () =
  let usage = "\
*** This program is provided for your convenience as part of the 
    json-wheel package for this particular version (" ^ Version.version ^ "). 
    There is no guarantee of compatibility with future versions. ***

Usage: jsoncat [options] file" 
  in
  let big_int_mode = ref false in
  let allow_comments = ref false in
  let allow_nan = ref false in
  let compact = ref false in
  let file_name = ref None in
  let run_test = ref false in
  let show_time = ref false in
  Arg.parse [
    "-big", Arg.Set big_int_mode, 
    "Accept large ints and represent them as strings";
    
    "-comments", Arg.Set allow_comments, 
    "Allow C-style comments";
    
    "-compact", Arg.Set compact,
    "Minimize the size of the output";
    
    "-nan", Arg.Set allow_nan,
    "Allow Javascript NaN, -Infinity and Infinity values";
    
    "-test", Arg.Set run_test, 
    "Some benchmarks";

    "-time", Arg.Set show_time,
    "Show execution times of parsing and printing";
  ]
    (fun f -> file_name := Some f)
    usage;
  
  if !run_test then (test (); print_newline (); test ())
  else
    let fn = 
      match !file_name with 
	  None -> eprintf "%s\n%!" usage; exit 1
	| Some fn -> fn
    in
    let j = 
      try
	let load = Json_io.load_json
		     ~allow_comments: !allow_comments 
		     ~allow_nan: !allow_nan
		     ~big_int_mode: !big_int_mode in
	if !show_time then time "Loading from file" load fn
	else load fn
      with
	  Json_error s -> eprintf "%s\n%!" s; exit 1
	| e -> raise e in
    let export = 
      Json_io.string_of_json ~allow_nan: !allow_nan ~compact:!compact in
    let result = 
      if !show_time then time "Converting to string" export j
      else export j in
    print_endline result
      
let _ = 
  if not !Sys.interactive then
    main ()
