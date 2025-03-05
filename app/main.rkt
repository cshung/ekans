; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../ekans/lexer.rkt")
(require "../ekans/parser.rkt")
(require "../ekans/codegen.rkt")

(define (log-info-input args)
  (displayln "[log] Arguments received:")
  (displayln args)
  (if (null? args)
      (displayln "[log] Please provide a file name.")
      (let ([filename (car args)]) (displayln (read-file filename)))))

(define (compiler filename)
  ; lexer
  ; (displayln (lexer (string->list "Hello World")))
  ;
  ; parser
  ; (displayln (parse-statements (string->list "I Go to School By Bus!"))))
  ;
  ; code generation
  (define input (read-file filename))
  (define parsed-program (parse-statements input))
  (if (eq? parsed-program 'error)
      (displayln "Error: Unable to parse the input.")
      (let ([generated-code (generate-code parsed-program)])
        (displayln generated-code)
        (displayln (generate-main-function parsed-program))
        (generate-file "build/main.c" (generate-main-function parsed-program)))))

(define (main)
  (define args (vector->list (current-command-line-arguments)))
  (log-info-input args)
  (if (null? args)
      (displayln "Error: No input file provided.")
      (compiler (car args))))

(provide main)

(main)
