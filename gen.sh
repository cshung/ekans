cat ./app/main.rkt > ./template
cat ./common/*.rkt >> ./template
cat ./ekans/*.rkt >> ./template
cat ./template | sed 's/#lang racket//g' | sed 's/.*provide.*//g' | sed 's/.*require.*//g' > ./test/data/debug.rkt
rm ./template
