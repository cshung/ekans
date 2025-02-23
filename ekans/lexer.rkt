#lang racket

(provide lexer read-file)

(define (lexer input)
  input)

(define (read-file filename)
  (call-with-input-file filename
    (lambda (port)
      (let ([content (port->string port)])  
        content))))