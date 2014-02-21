
# OCaml programs for compiling
OCAMLDEP = ocamldep
OCAMLC = ocamlc
OCAMLOPT = ocamlopt
OCAMLFIND = ocamlfind
OCAMLDOC = ocamldoc

# Libs to link with
REQUIRES = unix str

# Include dirs
INCLUDES = -I lib

# Install prefix for client
PREFIX = /usr/local

#Name
NAME=o9p

# Sources
LIBSRC = lib/fcall.ml lib/o9pc.ml

# The output to create
LIB = o9p.cma
LIBX = o9p.cmxa

# Automagic stuff below

LIBOBJ = $(patsubst %.ml,%.cmo,$(LIBSRC))
LIBXOBJ = $(patsubst %.ml,%.cmx,$(LIBSRC))
LIBCMI = $(patsubst %.ml,%.cmi,$(LIBSRC))
LIBMLI = $(patsubst %.ml,%.mli,$(LIBSRC))

all: $(LIB) $(LIBX)

.PHONY: install
install: all
	$(OCAMLFIND) install $(NAME) $(LIB) $(LIBCMI) $(NAME).a $(LIBX) META

.PHONY: uninstall
uninstall:
	$(OCAMLFIND) remove $(NAME)

$(LIB): $(LIBCMI) $(LIBOBJ)
	$(OCAMLFIND) $(OCAMLC) -a -o $@ -package "$(REQUIRES)" -linkpkg $(LIBOBJ)

$(LIBX): $(LIBCMI) $(LIBXOBJ)
	$(OCAMLFIND) $(OCAMLOPT) -a -o $@ -package "$(REQUIRES)" $(LIBXOBJ)

%.cmo: %.ml
	$(OCAMLFIND) $(OCAMLC) -c $(INCLUDES) -package "$(REQUIRES)" $<

%.cmi: %.mli
	$(OCAMLFIND) $(OCAMLC) -c $(INCLUDES) -package "$(REQUIRES)" $<

%.cmx: %.ml
	$(OCAMLFIND) $(OCAMLOPT) -c $(INCLUDES) -package "$(REQUIRES)" $<

htdoc: $(LIBCMI) $(LIBMLI)
	$(OCAMLDOC) -html -I lib -d doc $(LIBMLI)

.PHONY: clean
clean:
	rm -f lib/*.cmo lib/*.cmx lib/*.cmi lib/*.o \
	  $(LIB) $(LIBX) $(patsubst %.cmxa,%.a,$(LIBX)) doc/*
