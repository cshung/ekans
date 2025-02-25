#lang racket

(require rackunit
         "../ekans/lexer.rkt")
(require "../common/common.rkt")

(provide test-lexer)

(define-test-suite test-lexer
                   (test-case "Test EOF"
                     (check-equal? (lexer (string->list "")) ; Call the lexer function
                                   ; The token type is eof
                                   ; The token value for eof is nothing
                                   ; And there is no remaining input
                                   (cons (cons 'eof '()) '())))
                   (test-case "Test lparen"
                     (check-equal? (lexer (string->list "()"))
                                   ; The token type is lparen
                                   ; The token value for lparen is nothing
                                   ; And the remaining input is the rparen
                                   (cons (cons 'lparen '()) (list rp))))
                   (test-case "Test rparen"
                     (check-equal? (lexer (string->list ")("))
                                   ; The token type is rparen
                                   ; The token value for rparen is nothing
                                   ; And the remaining input is the lparen
                                   (cons (cons 'rparen '()) (list lp)))))
