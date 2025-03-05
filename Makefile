# Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
# Licensed under the MIT License. See the LICENSE file in the project root for details.

default: clean build execute compiled-c-code

fmt:
	find . -type f -iname "*.rkt" | xargs raco fmt -i --indent 2 # raco pkg install fmt

build: fmt
	mkdir -p build
	raco make app/main.rkt                # https://docs.racket-lang.org/raco/make.html
	raco exe -o build/compiler.out app/main.rkt # https://docs.racket-lang.org/raco/exe.html

execute:
	# for program in $$(find ./test/data/ -type f -iname "*.rkt"); do \
	#	./compiler.out $$program;                                     \
	# done
	./build/compiler.out test/data/int/testcase_001.rkt

clean:
	rm -rf *.out *.c build/

compiled-c-code:
	clang -o build/app.out build/main.c
	file build/app.out

test-compiler: fmt
	raco test test/main.rkt	

test-codegen: fmt
	raco test test/test-codegen.rkt

.PHONY: fmt build execute clean test
