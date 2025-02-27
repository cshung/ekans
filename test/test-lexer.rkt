#lang racket

(require rackunit
         "../ekans/lexer.rkt")
(require "../common/common.rkt")

(provide test-lexer)

(define-test-suite test-lexer
                   (test-case "Test EOF"
                     (check-equal? (lexer (string->list "")) (cons (cons 'eof '()) '())))
                   (test-case "Test lparen"
                     (check-equal? (lexer (string->list "()")) (cons (cons 'lparen '()) (list rp))))
                   (test-case "Test rparen"
                     (check-equal? (lexer (string->list ")(")) (cons (cons 'rparen '()) (list lp))))
                   (test-case "Test single digit"
                     (check-equal? (lexer (string->list "3")) (cons (cons 'number 3) '())))
                   (test-case "Test multiple digits"
                     (check-equal? (lexer (string->list "357")) (cons (cons 'number 357) '())))
                   (test-case "Test digit following a valid suffix case"
                     (check-equal? (lexer (string->list "357 "))
                                   (cons (cons 'number 357) '(#\space))))
                   (test-case "Test digit following an invalid suffix case"
                     (check-equal? (lexer (string->list "357a z")) (cons (cons 'unknown '()) '()))))
