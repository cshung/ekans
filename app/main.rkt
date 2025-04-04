; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "system.rkt")
(require "../ekans/parser.rkt")
(require "../ekans/codegen.rkt")

(define library
  "(define (map f lst) (if (null? lst) '() (cons (f (car lst)) (map f (cdr lst))))) (define (length lst) (if (null? lst) 0 (+ 1 (length (cdr lst)))))(define args (get-args))(define (filter pred lst)(cond[(null? lst) '()][(pred (car lst)) (cons (car lst) (filter pred (cdr lst)))][else (filter pred (cdr lst))]))(define (append lst1 lst2)(if (null? lst1)lst2(cons (car lst1) (append (cdr lst1) lst2))))(define (reverse lst)(define (helper lst acc)(if (null? lst)acc(helper (cdr lst) (cons (car lst) acc))))(helper lst '()))")

(define (compiler input-file output-file)
  (define input (string-append library (read-file input-file)))
  (define parsed-program (parse-statements (string->list input)))
  (if (eq? parsed-program 'error)
      (displayln "Error: Unable to parse the input.")
      (let ([generated-code (generate-all-code (car parsed-program))])
        (write-file output-file generated-code))))

(define (main)
  (if (< (length args) 2)
      (displayln "Usage: ./compiler.out input.rkt output.c")
      (compiler (car args) (cadr args))))

(provide main)

(main)
