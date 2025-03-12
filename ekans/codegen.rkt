; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../common/common.rkt")

(provide generate-code)
(provide generate-main-function)
(provide generate-file)

(define prologue "#include <ekans.h>\n\nint main(void) {\n  initialize_ekans();\n  collect();\n")
(define epilogue "  finalize_ekans();\n  return 0;\n}\n")

(define (generate-number-statement number-statement next-temp-id)
  (let ([number-value (cdr number-statement)])
    (cons (format "  v~a = create_number_value(~a);\n  print_ekans_value(v~a);\n  collect();\n"
                  next-temp-id
                  number-value
                  next-temp-id)
          (+ next-temp-id 1))))

(define (generate-bool-statement bool-statement next-temp-id)
  (let ([bool-value (cdr bool-statement)])
    (cons (format "  v~a = create_boolean_value(~a);\n  print_ekans_value(v~a);\n  collect();\n"
                  next-temp-id
                  (if bool-value "true" "false")
                  next-temp-id)
          (+ next-temp-id 1))))

(define (generate-statement statement next-temp-id)
  (displayln (format "[log] generate-statement: statement = ~a" statement))
  (let ([statement-type (car statement)])
    (cond
      [(eq? statement-type 'number-statement) (generate-number-statement statement next-temp-id)]
      [(eq? statement-type 'bool-statement) (generate-bool-statement statement next-temp-id)]
      [else (error (format "[log] Error: Unknown statement type ~a" statement-type))])))

(define (generate-statements statements next-temp-id)
  (displayln (format "[log] generate-statements: statements = ~a" statements))
  (if (null? statements)
      (cons empty-string next-temp-id)
      (let* ([first-statement-pair (generate-statement (car statements) next-temp-id)]
             [first-statement (car first-statement-pair)]
             [next-temp-id (cdr first-statement-pair)]
             [rest-statement-pair (generate-statements (cdr statements) next-temp-id)]
             [rest-statement (car rest-statement-pair)]
             [next-temp-id (cdr rest-statement-pair)])
        (cons (string-append first-statement rest-statement) next-temp-id))))

(define (generate-temp-declarations num-temps)
  (if (= num-temps 1)
      ""
      (string-append (generate-temp-declarations (- num-temps 1))
                     (format "  ekans_value* v~a = NULL;\n  push_stack_slot(&v~a);\n"
                             (- num-temps 1)
                             (- num-temps 1)))))

(define (generate-code parsed-program)
  (let* ([statements (car parsed-program)]
         [statements-pair (generate-statements statements 1)]
         [statements-code (car statements-pair)]
         [num-temps (cdr statements-pair)])
    (string-append (generate-temp-declarations num-temps)
                   statements-code
                   (format "  pop_stack_slot(~a);\n" (- num-temps 1)))))

(define (generate-main-function parsed-program)
  (let ([code (generate-code parsed-program)]) (string-append prologue code epilogue)))

(define (generate-file filename generated-code)
  (with-output-to-file filename (lambda () (write-string generated-code)) #:exists 'replace))
