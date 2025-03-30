; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../ekans/parser.rkt")
(require "../ekans/codegen.rkt")

(define (read-file filename)
  (call-with-input-file filename
                        (lambda (port) (let ([content (port->string port)]) (string->list content)))))

(define library
  (string->list
   "
(define (map f lst)
  (if (null? lst)
      '()
      (cons (f (car lst)) (map f (cdr lst)))))
"))

(define (compiler input-file output-file)
  (define input (append library (read-file input-file)))
  (define parsed-program (parse-statements input))
  (if (eq? parsed-program 'error)
      (displayln "Error: Unable to parse the input.")
      (let ([generated-code (generate-all-code (car parsed-program))])
        (generate-file output-file generated-code))))

(define (main)
  (define args (vector->list (current-command-line-arguments)))
  (if (< (length args) 2)
      (displayln "Usage: ./compiler.out input.rkt output.c")
      (begin
        (compiler (car args) (cadr args))
        (displayln "") ; Avoid printing some random number to the console
        )))

(provide main)

(main)
