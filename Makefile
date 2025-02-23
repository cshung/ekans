default: clean build execute

build:
	raco exe -o compiler.out app/main.rkt 

execute:
	./compiler.out program/math/add.rkt
	./compiler.out program/string/testcase_001.rkt

clean:
	rm -f *.out

test:
	raco test test/main.rkt	

.PHONY: build execute clean test
