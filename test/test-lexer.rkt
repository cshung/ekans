#lang racket

(require rackunit "../ekans/lexer.rkt")  
         
(provide test-lexer)  
         
(define-test-suite test-lexer
  (test-case "Test lexer"
    (check-equal? (lexer "hello world") ; Call the lexer function
                  "hello world")))      ; Expected output 