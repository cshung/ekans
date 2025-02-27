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
