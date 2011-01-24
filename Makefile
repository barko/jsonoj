VERSION = 1.0.6
export VERSION

RESULT = jsonwheel
NAME = json-wheel
ONAME = json_wheel
SOURCES = \
  json_type.mli json_type.ml \
  json_parser.mli json_parser.mly \
  json_lexer.mll \
  json_io.mli json_io.ml \
  json_compat.ml

PACKS = netstring

STDBIN = $(shell dirname `which ocamlfind`)
ifndef PREFIX
  PREFIX = $(shell dirname $(STDBIN))
endif
export PREFIX

ifndef BINDIR
  BINDIR = $(PREFIX)/bin
endif
export BINDIR

BYTERESULT = $(RESULT).cma json_*.cmo
OPTRESULT = $(RESULT).cmxa $(RESULT).a json_*.cmx json_*.o


.PHONY: default all opt install uninstall html archive test

default: bcl ncl jsoncat

all: bcl
opt: ncl jsoncat


install:
	$(MAKE) META
	ocamlfind install $(NAME) META json_*.cmi \
		json_type.mli json_io.mli json_compat.ml \
		`test -f $(RESULT).cma && echo $(BYTERESULT)` \
		`test -f $(RESULT).cmxa && echo $(OPTRESULT)`
	if test -f jsoncat$(EXE); \
		then install -m 0755 jsoncat$(EXE) $(BINDIR)/ ; \
		else : ; fi
uninstall:
	ocamlfind remove $(NAME)
	rm -f $(BINDIR)/jsoncat$(EXE)

version.ml: Makefile
	echo 'let version = "$(VERSION)"' > version.ml
jsoncat: version.ml jsoncat.ml
	$(MAKE) ncl
	ocamlfind ocamlopt -o jsoncat -package $(PACKS) -linkpkg \
		$(RESULT).cmxa version.ml jsoncat.ml

test: jsoncat
	./jsoncat -test
	cmp sample-compact.json sample-compact2.json
	cmp sample-indented.json sample-indented2.json
	rm sample-compact.json sample-compact2.json \
		sample-indented.json sample-indented2.json
check:
	@echo "-------------------- Standard mode --------------------"
	./check.sh
	@echo "--------------------- Big int mode --------------------"
	./check.sh -b
	@echo "Some of the tests are known to produce an ERROR, see README."


META: META.template Makefile
	echo 'name = "$(NAME)"' > META
	echo 'version = "$(VERSION)"' >> META
	cat META.template >> META

html:
	ocamldoc -d html -html json_type.mli json_io.mli json_compat.ml

archive: META html
		rm -rf /tmp/$(NAME) /tmp/$(NAME)-$(VERSION) && \
	 	cp -r . /tmp/$(NAME) && \
		cd /tmp/$(NAME) && \
			$(MAKE) clean && \
			rm -f *~ $(NAME)*.tar* && \
		cd /tmp && cp -r $(NAME) $(NAME)-$(VERSION) && \
		tar czf $(NAME).tar.gz $(NAME) && \
		tar cjf $(NAME).tar.bz2 $(NAME) && \
		tar czf $(NAME)-$(VERSION).tar.gz $(NAME)-$(VERSION) && \
		tar cjf $(NAME)-$(VERSION).tar.bz2 $(NAME)-$(VERSION)
	mv /tmp/$(NAME).tar.gz /tmp/$(NAME).tar.bz2 .
	mv /tmp/$(NAME)-$(VERSION).tar.gz /tmp/$(NAME)-$(VERSION).tar.bz2 .
	cp $(NAME).tar.gz $(NAME).tar.bz2 $$WWW/
	cp $(NAME)-$(VERSION).tar.gz $(NAME)-$(VERSION).tar.bz2 $$WWW/
	cp LICENSE $$WWW/$(NAME)-license.txt
	echo 'let $(ONAME)_version = "$(VERSION)"' \
		> $$WWW/$(NAME)-version.ml
	cp Changes $$WWW/$(NAME)-changes.txt
	mkdir -p $$WWW/$(NAME)-doc
	cp html/* $$WWW/$(NAME)-doc


TRASH = jsoncat jsoncat.o jsoncat.cm* version.* \
  sample-compact.json sample-compact2.json \
  sample-indented.json sample-indented2.json

OCAMLMAKEFILE = OCamlMakefile
include $(OCAMLMAKEFILE)
