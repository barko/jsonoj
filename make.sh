#!/bin/bash
set -x

function do_make () {
    ocamlfindjs ocamljs -c json_type.mli
    ocamlfindjs ocamljs -c json_type.ml

    ocamlyacc json_parser.mly
    ocamlfindjs ocamljs -c json_parser.mli
    ocamlfindjs ocamljs -c json_parser.ml

    ocamllex json_lexer.mll
    ocamlfindjs ocamljs -c json_lexer.ml -package javascript

    ocamlfindjs ocamljs -c json_io.mli
    ocamlfindjs ocamljs -c json_io.ml

    ocamlfindjs ocamljs -a -o jsonoj.cmjsa \
        -linkpkg -package javascript \
        json_type.cmjs json_lexer.cmjs json_parser.cmjs json_io.cmjs
}

function do_clean () {
    rm -rf *.cmi *.cmjs json_lexer.ml json_parser.ml json_parser.mli 
}

case $1 in
    clean)
    do_clean 
    ;;

    *)
    do_make
    ;;
esac

