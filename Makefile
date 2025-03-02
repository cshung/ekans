# Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
# Licensed under the MIT License. See the LICENSE file in the project root for details.

default: clean build execute

fmt:
	find . -type f -iname "*.rkt" | xargs raco fmt -i --indent 2 # raco pkg install fmt

build: fmt
	raco exe -o compiler.out app/main.rkt 

execute:
	./compiler.out program/math/add.rkt
	./compiler.out program/string/testcase_001.rkt

clean:
	rm -f *.out

test: fmt
	raco test test/main.rkt	

.PHONY: fmt build execute clean test
