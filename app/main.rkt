; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../ekans/lexer.rkt")
(require "../ekans/parser.rkt")
(require "../ekans/codegen.rkt")

(define (compiler filename)
  (define input (read-file filename))
  (define parsed-program (parse-statements input))
  (if (eq? parsed-program 'error)
      (displayln "Error: Unable to parse the input.")
      (let ([generated-code (generate-all-code (car parsed-program))])
        (generate-file "build/main.c" generated-code))))

(define (main)
  (define args (vector->list (current-command-line-arguments)))
  (if (null? args)
      (displayln "Error: No input file provided.")
      (begin
        (compiler (car args))
        (displayln "") ; Avoid printing some random number to the console
        )))

(provide main)

(main)
