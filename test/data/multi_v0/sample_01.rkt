; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

(define (factorial x)
  (if (= x 0)
      1
      (* (factorial (- x 1)) x)))
