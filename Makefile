# Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
# Licensed under the MIT License. See the LICENSE file in the project root for details.

default: clean build execute 

fmt:
	find . -type f -iname "*.rkt" | xargs raco fmt -i --indent 2 # raco pkg install fmt

build: fmt
	mkdir -p build
	raco make app/main.rkt                      # https://docs.racket-lang.org/raco/make.html
	raco exe -o build/compiler.out app/main.rkt # https://docs.racket-lang.org/raco/exe.html

execute:
	# for program in $$(find ./test/data/ -type f -iname "*.rkt"); do \
	#	./compiler.out $$program;                                       \
	# done
	./build/compiler.out test/data/bool.rkt

clean:
	rm -rf *.out *.c build/

test-compiled-c-code: build execute
	set -e
	clang -o build/app.out build/main.c
	./build/app.out > ./build/bool.actual
	diff ./test/data/bool.expect ./build/bool.actual
	diff -q ./test/data/bool.expect ./build/bool.actual >/dev/null

unit-tests: fmt
	raco test test/main.rkt

.PHONY: default fmt build execute clean test-compiled-c-code unit-tests
