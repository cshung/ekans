; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require rackunit
         rackunit/text-ui
         "../ekans/parser.rkt")

(define-test-suite
 test-parser
 (test-case "Test Number Statement"
   (check-equal? (parse-statement (string->list "123")) (cons (cons 'number-statement 123) '())))
 (test-case "Test Number Statement with trailing characters"
   (check-equal? (parse-statement (string->list "123 "))
                 (cons (cons 'number-statement 123) '(#\space))))
 (test-case "Test Empty Statements"
   (check-equal? (parse-statements (string->list "")) (cons '() '())))
 (test-case "Test One Number Statement"
   (check-equal? (parse-statements (string->list "123"))
                 (cons (list (cons 'number-statement 123)) '())))
 (test-case "Test Two Numbers Statement"
   (check-equal? (parse-statements (string->list "123 234"))
                 (cons (list (cons 'number-statement 123) (cons 'number-statement 234)) '())))
 (test-case "Test One Bool Statement"
   (check-equal? (parse-statements (string->list "#t")) (cons (list (cons 'bool-statement #t)) '())))
 (test-case "Test Two Bools Statement"
   (check-equal? (parse-statements (string->list "#t #f"))
                 (cons (list (cons 'bool-statement #t) (cons 'bool-statement #f)) '())))
 (test-case "Test Empty List"
   (check-equal? (parse-statements (string->list "()")) (cons (list (cons 'list-statement '())) '())))
 (test-case "Test List with One Number"
   (check-equal? (parse-statements (string->list "(123)"))
                 (cons (list (cons 'list-statement (list (cons 'number-statement 123)))) '())))
 (test-case "Test List with Two Numbers"
   (check-equal? (parse-statements (string->list "(123 234)"))
                 (cons (list (cons 'list-statement
                                   (list (cons 'number-statement 123) (cons 'number-statement 234))))
                       '())))
 (test-case "Test List with One Number One Bool"
   (check-equal? (parse-statements (string->list "(123 #t)"))
                 (cons (list (cons 'list-statement
                                   (list (cons 'number-statement 123) (cons 'bool-statement #t))))
                       '())))
 (test-case "Test Two Lists"
   (check-equal? (parse-statements (string->list "(123) (234)"))
                 (cons (list (cons 'list-statement (list (cons 'number-statement 123)))
                             (cons 'list-statement (list (cons 'number-statement 234))))
                       '())))
 (test-case "Test Quoted List"
   (check-equal? (parse-statements (string->list "'(123 234)"))
                 (cons (list ; The list of statements
                        (cons 'quote-statement
                              (cons 'list-statement ; The statement type
                                    (list (cons 'number-statement 123)
                                          (cons 'number-statement 234)))))
                       '())))
 (test-case "Test Symbol"
   (check-equal? (parse-statements (string->list "foo"))
                 (cons (list (cons 'symbol-statement "foo")) '())))
 (test-case "Test nested list"
   (check-equal? (parse-statements (string->list "(123 (234))"))
                 (cons (list (cons 'list-statement
                                   (list (cons 'number-statement 123)
                                         (cons 'list-statement (list (cons 'number-statement 234))))))
                       '())))
 (test-case "Test Character Statement"
   ; (displayln (string-append "[log][test-parser] Input: " (format "~a" (string->list "#\\a"))))
   ; (displayln (string-append "[log][test-parser] Expected output: "
   ;                           (format "~a" (cons (cons 'char-statement #\a) '()))))
   (check-equal? (parse-statement (string->list "#\\a")) (cons (cons 'char-statement #\a) '())))
 ; add more test cases here
 )

(run-tests test-parser)
