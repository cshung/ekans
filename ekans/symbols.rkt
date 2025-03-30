; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(provide initial-symbol-table)
(provide lookup)
(provide last-index-of)
(provide builtins)

(define builtins
  '(("+" "plus") ("-" "subtract")
                 ("*" "multiply")
                 ("/" "division")
                 ("char<=?" "char_le")
                 ("char>=?" "char_ge")
                 ("cons" "list_cons")
                 ("=" "equals")
                 ("eq?" "equals")
                 ("null?" "is_null")
                 ("car" "car")
                 ("cdr" "cdr")))

(define (initial-symbol-table)
  (cons (map car builtins) '()))

(define (last-index-of l target current index)
  (if (null? l)
      current
      (let ([head (car l)]
            [rest (cdr l)])
        (if (equal? head target)
            (last-index-of rest target (list index) (+ index 1))
            (last-index-of rest target current (+ index 1))))))

(define (lookup symbol table level)
  (if (null? table)
      (error (format "Symbol '~a' is not found" symbol))
      (let ([result (last-index-of (car table) symbol '() 0)])
        (if (null? result)
            (lookup symbol (cdr table) (+ level 1))
            (cons level result)))))
