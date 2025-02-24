#lang racket

(require "../common/common.rkt")

(provide lexer read-file)

(define (lexer input)
  (if (null? input)
    (cons (cons 'eof '()) '())
    (let
      ([peek (car input)])
      (cond
        [
          (equal? peek lp)
          (cons (cons 'lparen '()) (cdr input))
        ]
        [
          (equal? peek rp)
          (cons (cons 'rparen '()) (cdr input))
        ]
        [else
          (cons (cons 'unknown peek)
          (cdr input))
        ]
      ))))

(define (read-file filename)
  (call-with-input-file filename
    (lambda (port)
      (let ([content (port->string port)])
        (string->list content)))))