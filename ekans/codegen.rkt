; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../common/common.rkt")

(provide generate-code)
(provide generate-main-function)
(provide generate-file)

(define (temp-id context)
  (car context)
)

(define (num-temps context)
  (- (temp-id context) 1)
)

(define (increment-temp-id context)
  (cons (+ (car context) 1) (cdr context))
)

(define prologue "#include <ekans.h>\n\nint main(void) {\n  initialize_ekans();\n  collect();\n")
(define epilogue "  finalize_ekans();\n  return 0;\n}\n")

(define (generate-number-statement number-statement context)
  (let ([number-value (cdr number-statement)]
        [temp-id (temp-id context)])
    (cons (format "  v~a = create_number_value(~a);\n  print_ekans_value(v~a);\n  collect();\n"
                  temp-id
                  number-value
                  temp-id)
          (increment-temp-id context))))

(define (generate-bool-statement bool-statement context)
  (let ([bool-value (cdr bool-statement)]
        [temp-id (temp-id context)])
    (cons (format "  v~a = create_boolean_value(~a);\n  print_ekans_value(v~a);\n  collect();\n"
                  temp-id
                  (if bool-value "true" "false")
                  temp-id)
          (increment-temp-id context))))

(define (generate-statement statement context)
  (displayln (format "[log] generate-statement: statement = ~a" statement))
  (let ([statement-type (car statement)])
    (cond
      [(eq? statement-type 'number-statement) (generate-number-statement statement context)]
      [(eq? statement-type 'bool-statement) (generate-bool-statement statement context)]
      [else (error (format "[log] Error: Unknown statement type ~a" statement-type))])))

(define (generate-statements statements context)
  (displayln (format "[log] generate-statements: statements = ~a" statements))
  (if (null? statements)
      (cons empty-string context)
      (let* ([first-statement-pair (generate-statement (car statements) context)]
             [first-statement (car first-statement-pair)]
             [context (cdr first-statement-pair)]
             [rest-statement-pair (generate-statements (cdr statements) context)]
             [rest-statement (car rest-statement-pair)]
             [context (cdr rest-statement-pair)])
        (cons (string-append first-statement rest-statement) context))))

(define (generate-temp-declarations num-temps)
  (if (= num-temps 0)
      ""
      (string-append (generate-temp-declarations (- num-temps 1))
                     (format "  ekans_value* v~a = NULL;\n  push_stack_slot(&v~a);\n"
                             num-temps
                             num-temps))))

(define (generate-code parsed-program)
  (let* ([statements (car parsed-program)]
         [statements-pair (generate-statements statements '(1))]
         [statements-code (car statements-pair)]
         [context (cdr statements-pair)]
         [num-temps (num-temps context)])
    (string-append (generate-temp-declarations num-temps)
                   statements-code
                   (format "  pop_stack_slot(~a);\n" num-temps))))

(define (generate-main-function parsed-program)
  (let ([code (generate-code parsed-program)]) (string-append prologue code epilogue)))

(define (generate-file filename generated-code)
  (with-output-to-file filename (lambda () (write-string generated-code)) #:exists 'replace))
