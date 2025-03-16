# Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
# Licensed under the MIT License. See the LICENSE file in the project root for details.

DIR_BUILD    = build
DIR_INCLUDE  = inc
DIR_APP      = app
DIR_RUNTIME  = runtime
DIR_TEST     = test
DIR_TESTDATA = $(DIR_TEST)/data

INCLUDES = -I./$(DIR_INCLUDE)
CFLAGS   = -fsanitize=address -Wall -Werror -g
LDFLAGS  = -lasan
CC       = clang
CC0      = $(DIR_BUILD)/compiler-phase-0.out
CC1      = $(DIR_BUILD)/compiler-phase-1.out

default: clean build test-phase-0 test-phase-1

clean:
	rm -f *.out *.c 
	rm -rf $(DIR_BUILD)
	find . -type d -name "compiled" -exec rm -rf {} +

fmt:
	find . -type f -iname "*.rkt" | xargs raco fmt -i --indent 2
	find . -type f -iname "*.c" -o -iname "*.h" | xargs clang-format -i -style=file

build: $(CC0)
 
$(CC0): $(DIR_APP)/main.rkt $(DIR_BUILD)/ekans.o
	mkdir -p $(DIR_BUILD)
	raco make $<      # https://docs.racket-lang.org/raco/make.html
	raco exe -o $@ $< # https://docs.racket-lang.org/raco/exe.html

$(DIR_BUILD)/ekans.o: $(DIR_RUNTIME)/ekans.c
	mkdir -p $(DIR_BUILD)
	$(CC) $(INCLUDES) $(CFLAGS) -c -o $@ $?

test-phase-0: $(DIR_BUILD)/main.c

$(DIR_BUILD)/main.c: $(CC0)
	# for program in $$(find $(DIR_TESTDATA) -type f -iname "*.rkt"); do \
	#   $< $$program;                                                    \
	# done
	#
	$< $(DIR_TESTDATA)/debug.rkt

test-phase-1: $(DIR_BUILD)/main.c $(DIR_BUILD)/ekans.o
	$(CC) $(INCLUDES) $(CFLAGS) -o $(CC1) $?
	$(CC1)

test-all-phases: test-phase-0 test-phase-1
	set -e;                                                                             \
	for file in $$(find $(DIR_TESTDATA) -name '*.rkt' | sed 's/\.rkt$$//'); do          \
		if [ -f "$$file.expect" ]; then                                                   \
			rm -f $(DIR_BUILD)/output.actual;                                               \
			$(CC0) "$$file.rkt";                                                            \
			$(CC) $(INCLUDES) $(CFLAGS) -o $(CC1) $(DIR_BUILD)/main.c $(DIR_BUILD)/ekans.o; \
			$(CC1) > $(DIR_BUILD)/output.actual;                                            \
			echo "Input";                                                                   \
			cat "$$file.rkt";                                                               \
			echo "Output";                                                                  \
			cat $(DIR_BUILD)/output.actual;                                                 \
			diff "$$file.expect" $(DIR_BUILD)/output.actual;                                \
			diff -q "$$file.expect" $(DIR_BUILD)/output.actual >/dev/null;                  \
		fi;                                                                               \
	done

test-lexer: test/test-lexer.rkt
	raco test $<

test-parser: test/test-parser.rkt
	raco test $<

test-runtime: $(DIR_BUILD)/ekans.o
	$(CC) $(INCLUDES) $(CFLAGS) -o $(DIR_BUILD)/$@.out $(DIR_TEST)/runtime/main.c $<
	# ASAN_OPTIONS=detect_leaks=1 $(DIR_BUILD)/$@.out # OSX doesn't work
	$(DIR_BUILD)/$@.out

test-all: clean fmt test-lexer test-parser test-runtime test-all-phases 

.PHONY: default clean fmt build test-phase-0 test-phase-1 test-all-phases test-lexer test-parser test-runtime test-all
