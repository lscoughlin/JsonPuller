# JsonPuller - Free Pascal JSON pull parser
#
#   make          build the library units
#   make test     build and run the fpcunit suite
#   make examples build and run each example
#   make clean    remove build outputs

FPC      ?= fpc
FPCVER   := $(shell $(FPC) -iV)
FPCCPU   := $(shell $(FPC) -iTP)
FPCOS    := $(shell $(FPC) -iTO)
UNITS    ?= /usr/local/lib/fpc/$(FPCVER)/units/$(FPCCPU)-$(FPCOS)
FPCFLAGS ?= -Mdelphi -vw -Fu./src \
            -Fu$(UNITS)/fcl-fpcunit -Fu$(UNITS)/fcl-json -Fu$(UNITS)/fcl-base \
            -Fu$(UNITS)/rtl -Fu$(UNITS)/rtl-objpas -Fu$(UNITS)/rtl-extra
BIN       = bin

EXAMPLES = example_string example_bytes example_stream example_file \
           example_events example_section example_comment example_dialect \
           example_quotes example_missing example_numbers

.PHONY: all test examples clean

all:
	@if grep -q "automatically created by Lazarus" JsonPuller.pas 2>/dev/null; then rm -f JsonPuller.pas; fi
	@mkdir -p $(BIN)
	$(FPC) $(FPCFLAGS) -Cn -FE$(BIN) -FU$(BIN) src/JsonPuller.pas

examples: all
	@mkdir -p $(BIN)
	@for ex in $(EXAMPLES); do \
	  $(FPC) $(FPCFLAGS) -FE$(BIN) -FU$(BIN) examples/$$ex.pas >/dev/null || exit 1; \
	done
	@for ex in $(EXAMPLES); do \
	  (cd examples && ../$(BIN)/$$ex) >/dev/null || exit 1; \
	done
	@echo "examples: PASS"

test: all
	$(FPC) $(FPCFLAGS) -Fu./test -FE$(BIN) -FU$(BIN) test/JsonPuller.RunTests.pas
	$(BIN)/JsonPuller.RunTests --all --format=plain --sparse

clean:
	rm -rf $(BIN) src/*.o src/*.ppu test/*.o test/*.ppu examples/*.o examples/*.ppu
