; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../common/common.rkt")

(provide generate-code)
(provide generate-main-function)
(provide generate-file)

(define prologue "#include <stdio.h>\n\nint main(void) {\n")
(define epilogue "  return 0;\n}\n")

(define (generate-number-statement number-statement)
  (let ([number-value (cdr number-statement)]) (format "  printf(\"%d\\n\",~a);\n" number-value)))

(define (generate-bool-statement bool-statement)
  (let ([bool-value (cdr bool-statement)])
    (if bool-value "  printf(\"#t\\n\");\n" "  printf(\"#f\\n\");\n")))

(define (generate-statement statement)
  (displayln (format "[log] generate-statement: statement = ~a" statement))
  (let ([statement-type (car statement)])
    (cond
      [(eq? statement-type 'number-statement) (generate-number-statement statement)]
      [(eq? statement-type 'bool-statement) (generate-bool-statement statement)]
      [else (error (format "[log] Error: Unknown statement type ~a" statement-type))])))

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
  (let ([code (generate-code parsed-program)]) (string-append prologue code epilogue)))

(define (generate-file filename generated-code)
  (with-output-to-file filename (lambda () (write-string generated-code)) #:exists 'replace))
