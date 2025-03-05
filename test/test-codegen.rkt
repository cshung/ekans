; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require rackunit
         rackunit/text-ui
         "../ekans/parser.rkt"
         "../ekans/codegen.rkt")

(provide test-codegen)

(define-test-suite
 test-codegen
 (test-case "Generate code for a single number"
   (define input (string->list "123"))
   (define parsed-program (parse-statements input))
   (check-not-equal? parsed-program 'error "Parsed program should not be an error")
   (define generated-code (generate-code parsed-program))
   (check-equal? generated-code "int num = 123;" "Generated code should be 'int num = 123;'")))

(run-tests test-codegen)
