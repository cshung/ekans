(let ([factorial (lambda (n self)
                   (if (= n 0)
                       1
                       (* n (self (- n 1) self))))])
  (factorial 5 factorial))
