; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

(let ([factorial (lambda (n self)
                   (if (= n 0)
                       1
                       (* n (self (- n 1) self))))])
  (factorial 5 factorial))
