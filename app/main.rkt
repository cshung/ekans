; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../ekans/lexer.rkt")
(require "../ekans/parser.rkt")

(define (compiler args)
  (displayln "Arguments received:")
  (displayln args)
  (if (null? args)
      (displayln "Please provide a file name.")
      (let ([filename (car args)]) (displayln (read-file filename)))))

(define (main)
  (compiler (vector->list (current-command-line-arguments)))
  (displayln (lexer (string->list "Hello World")))
  (displayln (parse-statements (string->list "I Go to School By Bus!"))))

(provide main)

(main)
