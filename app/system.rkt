; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(provide read-file)
(provide write-file)
(provide args)

(define (read-file filename)
  (call-with-input-file filename (lambda (port) (port->string port))))

(define (write-file filename generated-code)
  (with-output-to-file filename (lambda () (write-string generated-code)) #:exists 'replace))

(define args (vector->list (current-command-line-arguments)))
