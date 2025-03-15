# Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
# Licensed under the MIT License. See the LICENSE file in the project root for details.

INCLUDES = -I./inc
CFLAGS   = -fsanitize=address -Wall -Werror -g
LDFLAGS  = -lasan

default: clean build execute

fmt:
	find . -type f -iname "*.rkt" | xargs raco fmt -i --indent 2
	find . -type f -iname "*.c" -o -iname "*.h" | xargs clang-format -i -style=file

build: fmt build/ekans.o
	mkdir -p build
	raco make app/main.rkt                      # https://docs.racket-lang.org/raco/make.html
	raco exe -o build/compiler.out app/main.rkt # https://docs.racket-lang.org/raco/exe.html

build/ekans.o:	inc/ekans.h runtime/ekans.c
	mkdir -p build
	clang -g -I inc -c -o build/ekans.o runtime/ekans.c

execute: clean build
	# for program in $$(find ./test/data/ -type f -iname "*.rkt"); do \
	#	./compiler.out $$program;                                       \
	# done
	#
	./build/compiler.out test/data/number.rkt
	#
	./build/compiler.out test/data/bool.rkt

clean:
	rm -rf *.out *.c build/

test-all: clean unit-tests test-compiled-c-code test-runtime

test-compiled-c-code: build
	set -e;                                                                      \
	for file in $$(find test/data -name '*.rkt' | sed 's/\.rkt$$//'); do         \
		if [ -f "$$file.expect" ]; then                                            \
			rm -f ./build/output.actual;                                             \
			./build/compiler.out "$$file.rkt";                                       \
			clang $(INCLUDES) $(CFLAGS) -o build/app.out build/main.c build/ekans.o; \
			./build/app.out > ./build/output.actual;                                 \
			diff "$$file.expect" ./build/output.actual;                              \
			diff -q "$$file.expect" ./build/output.actual >/dev/null;                \
		fi;                                                                        \
	done

test-runtime: clean fmt
	mkdir -p build
	clang $(INCLUDES) $(CFLAGS) -c -o build/ekans.o runtime/ekans.c
	clang $(INCLUDES) $(CFLAGS) -o build/test-runtime.out test/runtime/main.c build/ekans.o
	# ASAN_OPTIONS=detect_leaks=1 ./build/test-runtime.out # OSX doesn't work
	./build/test-runtime.out

unit-tests: fmt
	raco test test/main.rkt

.PHONY: default fmt build execute clean test-compiled-c-code unit-tests
