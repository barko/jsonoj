all:
	ocamlbuild jsonoj.cma
clean:
	ocamlbuild -clean
install:
	ocamlfind install jsonoj META _build/*.cm?
remove:
	ocamlfind remove jsonoj
