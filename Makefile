# Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
# Licensed under the MIT License. See the LICENSE file in the project root for details.

INCLUDES = -I./inc
CFLAGS   = -fsanitize=address -Wall -Werror -g
LDFLAGS  = -lasan
CC       = clang
CC0      = ./build/compiler-phase-0.out
CC1      = ./build/compiler-phase-1.out

default: clean build test-phase-0 test-phase-1

clean:
	rm -rf *.out *.c build/

fmt:
	find . -type f -iname "*.rkt" | xargs raco fmt -i --indent 2
	find . -type f -iname "*.c" -o -iname "*.h" | xargs clang-format -i -style=file

build: fmt build/ekans.o
	mkdir -p build
	raco make app/main.rkt          # https://docs.racket-lang.org/raco/make.html
	raco exe -o $(CC0) app/main.rkt # https://docs.racket-lang.org/raco/exe.html

build/ekans.o: runtime/ekans.c
	mkdir -p build
	$(CC) $(INCLUDES) $(CFLAGS) -c -o $@ $?

test-phase-0: clean build
	# for program in $$(find ./test/data/ -type f -iname "*.rkt"); do \
	#   $(CC0) $$program;                                             \
	# done
	#
	$(CC0) test/data/mul_t3.rkt

test-phase-1: test-phase-0
	$(CC) $(INCLUDES) $(CFLAGS) -o $(CC1) ./build/main.c build/ekans.o
	$(CC1)

test-all-phases: build
	set -e;                                                               \
	for file in $$(find test/data -name '*.rkt' | sed 's/\.rkt$$//'); do  \
		if [ -f "$$file.expect" ]; then                                     \
			rm -f ./build/output.actual;                                      \
			$(CC0) "$$file.rkt";                                              \
			$(CC) $(INCLUDES) $(CFLAGS) -o $(CC1) build/main.c build/ekans.o; \
			$(CC1) > ./build/output.actual;                                   \
			diff "$$file.expect" ./build/output.actual;                       \
			diff -q "$$file.expect" ./build/output.actual >/dev/null;         \
		fi;                                                                 \
	done

test-lexer: fmt
	raco test test/test-lexer.rkt

test-parser: fmt
	raco test test/test-parser.rkt

test-runtime: clean fmt
	mkdir -p build
	$(CC) $(INCLUDES) $(CFLAGS) -c -o build/ekans.o runtime/ekans.c
	$(CC) $(INCLUDES) $(CFLAGS) -o build/test-runtime.out test/runtime/main.c build/ekans.o
	# ASAN_OPTIONS=detect_leaks=1 ./build/test-runtime.out # OSX doesn't work
	./build/test-runtime.out

test-all: clean test-lexer test-parser test-runtime test-all-phases 

.PHONY: default clean fmt build test-phase-0 test-phase-1 test-all-phases test-lexer test-parser test-runtime test-all
