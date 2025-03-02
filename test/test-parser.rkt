; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require rackunit
         "../ekans/parser.rkt")

(provide test-parser)

(define-test-suite
 test-parser
 (test-case "Test Error Statement"
   (check-equal? (parse-statement (string->list "x")) 'error))
 (test-case "Test Number Statement"
   (check-equal? (parse-statement (string->list "123")) (cons (cons 'number-statement 123) '())))
 (test-case "Test Number Statement with trailing characters"
   (check-equal? (parse-statement (string->list "123 "))
                 (cons (cons 'number-statement 123) '(#\space))))
 (test-case "Test Error Statements"
   (check-equal? (parse-statements (string->list "x")) 'error))
 (test-case "Test Empty Statements"
   (check-equal? (parse-statements (string->list "")) (cons '() '())))
 (test-case "Test One Number Statement"
   (check-equal? (parse-statements (string->list "123"))
                 (cons (list (cons 'number-statement 123)) '())))
 (test-case "Test Two Number Statement"
   (check-equal? (parse-statements (string->list "123 234"))
                 (cons (list (cons 'number-statement 123) (cons 'number-statement 234)) '()))))
