# Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
# Licensed under the MIT License. See the LICENSE file in the project root for details.

default: clean build execute 

fmt:
	find . -type f -iname "*.rkt" | xargs raco fmt -i --indent 2 # raco pkg install fmt

build: fmt build/ekan.o
	mkdir -p build
	raco make app/main.rkt                      # https://docs.racket-lang.org/raco/make.html
	raco exe -o build/compiler.out app/main.rkt # https://docs.racket-lang.org/raco/exe.html

build/ekan.o:	runtime/ekan.c
	mkdir -p build
	clang -c -o build/ekan.o runtime/ekan.c

execute:
	# for program in $$(find ./test/data/ -type f -iname "*.rkt"); do \
	#	./compiler.out $$program;                                     \
	# done
	./build/compiler.out test/data/bool.rkt

clean:
	rm -rf *.out *.c build/

test-compiled-c-code: build
	set -e
	for file in $$(find test/data -name '*.rkt' | sed 's/\.rkt$$//'); do \
		if [ -f "$$file.expect" ]; then                                  \
			rm -f ./build/output.actual;                                 \
			./build/compiler.out "$$file.rkt";                           \
			clang -o build/app.out build/main.c build/ekan.o;            \
			./build/app.out > ./build/output.actual;                     \
			diff "$$file.expect" ./build/output.actual;                  \
			diff -q "$$file.expect" ./build/output.actual >/dev/null;    \
		fi;                                                              \
	done


unit-tests: fmt
	raco test test/main.rkt

.PHONY: default fmt build execute clean test-compiled-c-code unit-tests
