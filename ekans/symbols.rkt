; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(provide initial-symbol-table)
(provide lookup)
(provide last-index-of)
(provide builtins)

(define builtins
  '(("+" "plus") ; ekans_value* plus(ekans_value* environment);
    ("-" "subtract") ; ekans_value* subtract(ekans_value* environment);
    ("*" "multiply") ; ekans_value* multiply(ekans_value* environment);
    ("/" "division") ; ekans_value* division(ekans_value* environment)
    ("cons" "list_cons") ; void list_cons(ekans_value* environment, ekans_value** pReturn);
    ("=" "equals") ; void equals(ekans_value* environment, ekans_value** pReturn);
    ))

(define (initial-symbol-table defines)
  (cons (map car defines) (cons (map car builtins) '())))

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
      '()
      (let ([result (last-index-of (car table) symbol '() 0)])
        (if (null? result)
            (lookup symbol (cdr table) (+ level 1))
            (cons level result)))))
