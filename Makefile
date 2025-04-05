# Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
# Licensed under the MIT License. See the LICENSE file in the project root for details.

INCLUDES = -I./inc
CFLAGS   = -fsanitize=address -Wall -Werror -g
CC       = clang

# Variables for sources
RACKET_SOURCES = $(shell find . -type f -iname "*.rkt" -not -name "debug.rkt")
C_SOURCES = $(shell find . -type f \( -iname "*.c" -o -iname "*.h" \) -not -path "./build/*")

# Timestamp files
RACKET_TIMESTAMP = ./build/racket-time-stamp
C_TIMESTAMP = ./build/c-time-stamp

.PHONY: default build clean build-runtime build-compiler format-racket format-c fmt test-racket test-runtime

default: build

build: build-runtime build-compiler

build-runtime: format-c build/ekans.o

build-compiler: build/compiler.out

format-racket: $(RACKET_TIMESTAMP)

format-c: $(C_TIMESTAMP)

fmt: format-racket format-c

build/compiler.out: $(RACKET_TIMESTAMP) $(RACKET_SOURCES)
	mkdir -p build
	raco make app/main.rkt
	raco exe -o build/compiler.out app/main.rkt

build/ekans.o: $(C_TIMESTAMP) inc/ekans.h inc/ekans-internals.h runtime/ekans.c
	mkdir -p build
	$(CC) $(INCLUDES) $(CFLAGS) -c -o ./build/ekans.o ./runtime/ekans.c

$(RACKET_TIMESTAMP): $(RACKET_SOURCES)
	mkdir -p build
	find . -type f -iname "*.rkt" | xargs raco fmt -i --indent 2
	touch $@

$(C_TIMESTAMP): $(C_SOURCES)
	mkdir -p build
	find . -type f -iname "*.c" -o -iname "*.h" | xargs clang-format -i -style=file
	touch $@

build/test-runtime.out: build/ekans.o test/runtime/main.c
	mkdir -p build
	$(CC) $(INCLUDES) $(CFLAGS) -o build/test-runtime.out test/runtime/main.c build/ekans.o

test-all: test-racket test-runtime test-execution test-self-hosting

test-phase-0: build/debug.c

test-phase-1: build/debug.txt

test-racket: fmt
	raco test test/test-lexer.rkt
	raco test test/test-parser.rkt

test-lexer: fmt
	raco test test/test-lexer.rkt

test-multi-files: clean build/compiler.out build/ekans.o 
	for multi in multi_v0 multi_v1; do                                                  \
		rm -f "test/data/$$multi/output.rkt";                                             \
		python3 script/merge_files.py "test/data/$$multi" "test/data/$$multi/output.rkt"; \
		./build/compiler.out "test/data/$$multi/output.rkt" build/output.c;               \
		$(CC) $(INCLUDES) $(CFLAGS) -o build/output.out build/output.c build/ekans.o;     \
		./build/output.out;                                                               \
	done

test-runtime: fmt build/test-runtime.out
	./build/test-runtime.out

test-execution: ./build/compiler.out build/ekans.o
	set -e;                                                                             \
	for file in $$(find test/data -name '*.rkt' | sed 's/^.*\/\(.*\)\.rkt$$/\1/g'); do  \
		printf "\ntest input file: %s\n" "test/data/$$file.rkt";                          \
		if [ -f "test/data/$$file.expect" ]; then                                         \
			rm -f ./build/output.actual;                                                    \
			./build/compiler.out "test/data/$$file.rkt" "build/$$file.c";                   \
			$(CC) $(INCLUDES) $(CFLAGS) -o ./build/$$file.out build/$$file.c build/ekans.o; \
			./build/$$file.out > ./build/$$file.actual;                                     \
			echo "Input";                                                                   \
			cat "test/data/$$file.rkt";                                                     \
			echo "Output";                                                                  \
			cat ./build/$$file.actual;                                                      \
			diff "test/data/$$file.expect" ./build/$$file.actual;                           \
			diff -q "test/data/$$file.expect" ./build/$$file.actual >/dev/null;             \
		fi;                                                                               \
	done

test-self-hosting: ./build/debug.out build/ekans.o
	set -e;                                                                             \
	for file in $$(find test/data -name '*.rkt' | sed 's/^.*\/\(.*\)\.rkt$$/\1/g'); do  \
		printf "\ntest input file: %s\n" "test/data/$$file.rkt";                          \
		if [ -f "test/data/$$file.expect" ]; then                                         \
			rm -f ./build/output.actual;                                                    \
			./build/debug.out "test/data/$$file.rkt" "build/$$file.c";                      \
			$(CC) $(INCLUDES) $(CFLAGS) -o ./build/$$file.out build/$$file.c build/ekans.o; \
			./build/$$file.out > ./build/$$file.actual;                                     \
			echo "Input";                                                                   \
			cat "test/data/$$file.rkt";                                                     \
			echo "Output";                                                                  \
			cat ./build/$$file.actual;                                                      \
			diff "test/data/$$file.expect" ./build/$$file.actual;                           \
			diff -q "test/data/$$file.expect" ./build/$$file.actual >/dev/null;             \
		fi;                                                                               \
	done

test-debug: build/debug.out
	./build/debug.out ./test/data/debug.rkt ./build/debug.c

build/debug.c: build/compiler.out test/data/debug.rkt
	rm -f ./test/data/debug.rkt
	sh ./gen.sh
	./build/compiler.out ./test/data/debug.rkt ./build/debug.c

build/debug.out: build/debug.c build/ekans.o
	$(CC) $(INCLUDES) $(CFLAGS) -o ./build/debug.out ./build/debug.c ./build/ekans.o;

build/debug.txt: build/debug.out
	./build/debug.out > ./build/debug.txt

clean:
	@echo "Cleaning up build files..."
	rm -rf build
