; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../common/common.rkt")

(provide generate-code)
(provide generate-main-function)
(provide generate-file)

(define (generate-number-statement number-statement)
  (let ([number-value (cdr number-statement)]) (format "int num = ~a;" number-value)))

(define (generate-statement statement)
  (displayln (format "[log] generate-statement: statement = ~a" statement))
  (let ([statement-type (car statement)])
    (cond
      [(eq? statement-type 'number-statement) (generate-number-statement statement)]
      [else empty-string])))

(define (generate-statements statements)
  (displayln (format "[log] generate-statements: statements = ~a" statements))
  (if (null? statements)
      empty-string
      (let* ([first-statement (generate-statement (car statements))]
             [rest-statement (generate-statements (cdr statements))])
        (string-append first-statement rest-statement))))

(define (generate-code parsed-program)
  (let ([statements (car parsed-program)]) (generate-statements statements)))

(define (generate-main-function parsed-program)
  (let ([code (generate-code parsed-program)]) (string-append prologue "  " code "\n" epilogue)))

(define (generate-file filename generated-code)
  (with-output-to-file filename (lambda () (write-string generated-code)) #:exists 'replace))
