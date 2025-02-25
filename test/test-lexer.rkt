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
                                   (cons (cons 'rparen '()) (list lp))))
                   (test-case "Test digit (equal)"
                     (check-equal? (lexer (string->list "357"))
                                   ; The token type is digit
                                   (cons (cons 'digit #\3) (list #\5 #\7))))
                   (test-case "Test digit (not equal)"
                     (check-not-equal? (lexer (string->list "2240"))
                                       ; The token type is digit
                                       (cons (cons 'digit #\2) (list #\2 #\4 #\1)))))
