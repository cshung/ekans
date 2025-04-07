# Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
# Licensed under the MIT License. See the LICENSE file in the project root for details.

INCLUDES = -I./inc
CFLAGS   = -fsanitize=address -Wall -Werror -g
CC       = clang

# Variables for sources
C_SOURCES = $(shell find . -type f \( -iname "*.c" -o -iname "*.h" \) -not -path "./build/*")

# Timestamp files
C_TIMESTAMP = ./build/c-time-stamp

.PHONY: default build clean build-runtime build-lkg-compiler build-dev-compiler format-c fmt test-runtime

default: build

build: build-runtime build-lkg-compiler build-dev-compiler

build-runtime: format-c build/ekans.o

build-lkg-compiler: build/compiler.lkg.out

build-dev-compiler: build/compiler.dev.out

format-c: $(C_TIMESTAMP)

fmt: format-c

build/compiler.lkg.out: inc/ekans.h inc/ekans-internals.h runtime/ekans.c compiler/compiler.lkg.c build/ekans.o
	mkdir -p build
	$(CC) $(INCLUDES) $(CFLAGS) -o ./build/compiler.lkg.out ./compiler/compiler.lkg.c ./build/ekans.o

build/compiler.dev.out: inc/ekans.h inc/ekans-internals.h runtime/ekans.c build/compiler.dev.c build/ekans.o
	mkdir -p build
	$(CC) $(INCLUDES) $(CFLAGS) -o ./build/compiler.dev.out ./build/compiler.dev.c ./build/ekans.o

build/compiler.dev.c: build/compiler.lkg.out
	build/compiler.lkg.out ./compiler/compiler.dev.ekans ./build/compiler.dev.c

build/ekans.o: $(C_TIMESTAMP) inc/ekans.h inc/ekans-internals.h runtime/ekans.c
	mkdir -p build
	$(CC) $(INCLUDES) $(CFLAGS) -c -o ./build/ekans.o ./runtime/ekans.c

$(C_TIMESTAMP): $(C_SOURCES)
	mkdir -p build
	find . -type f -iname "*.c" -o -iname "*.h" | xargs clang-format -i -style=file
	touch $@

build/test-runtime.out: build/ekans.o test/runtime/main.c
	mkdir -p build
	$(CC) $(INCLUDES) $(CFLAGS) -o build/test-runtime.out test/runtime/main.c build/ekans.o

test-all: test-runtime test-execution

test-runtime: fmt build/test-runtime.out
	./build/test-runtime.out

test-execution: ./build/compiler.dev.out build/ekans.o
	set -e;                                                                             \
	for file in $$(find test/data -name '*.ekans' | sed 's/^.*\/\(.*\)\.ekans$$/\1/g'); do  \
		printf "\ntest input file: %s\n" "test/data/$$file.ekans";                          \
		if [ -f "test/data/$$file.expect" ]; then                                         \
			rm -f ./build/output.actual;                                                    \
			./build/compiler.dev.out "test/data/$$file.ekans" "build/$$file.c";               \
			$(CC) $(INCLUDES) $(CFLAGS) -o ./build/$$file.out build/$$file.c build/ekans.o; \
			./build/$$file.out > ./build/$$file.actual;                                     \
			echo "Input";                                                                   \
			cat "test/data/$$file.ekans";                                                     \
			echo "Output";                                                                  \
			cat ./build/$$file.actual;                                                      \
			diff "test/data/$$file.expect" ./build/$$file.actual;                           \
			diff -q "test/data/$$file.expect" ./build/$$file.actual >/dev/null;             \
		fi;                                                                               \
	done

clean:
	@echo "Cleaning up build files..."
	rm -rf build

perf: build/compiler.dev.out
	sudo perf record -g build/compiler.dev.out ./compiler/compiler.dev.ekans ./build/compiler.dev.c

perf-report:
	sudo perf report