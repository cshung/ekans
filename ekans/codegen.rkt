; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../common/common.rkt")

(provide generate-code)
(provide generate-main-function)
(provide generate-file)

(define (fetch-variable-id context)
  (car context))

(define (number-of-variables context)
  (- (fetch-variable-id context) 1))

(define (increment-variable-id context)
  (cons (+ (car context) 1) (cdr context)))

(define prologue "#include <ekans.h>\n\nvoid f1(ekans_value* env) {\n")

(define (generate-print-ekans-value-statement a)
  (format "  print_ekans_value(v~a);\n" a))

(define generate-collect-statement "  collect();\n")

(define (generate-number-statement number-statement context)
  (let ([number-value (cdr number-statement)]
        [variable-id (fetch-variable-id context)]
        [increment-context (increment-variable-id context)])
    (list (format "  v~a = create_number_value(~a);\n" variable-id number-value)
          variable-id
          increment-context)))

(define (generate-bool-statement bool-statement context)
  (let ([bool-value (cdr bool-statement)]
        [variable-id (fetch-variable-id context)]
        [increment-context (increment-variable-id context)])
    (list (format "  v~a = create_boolean_value(~a);\n" variable-id (if bool-value "true" "false"))
          variable-id
          increment-context)))

(define (generate-symbol-statement symbol-statement context)
  (let* ([symbol-value (cdr symbol-statement)]
         [variable-id (fetch-variable-id context)]
         [increment-context (increment-variable-id context)]
         [lookup-result (lookup symbol-value (initial-symbol-table '()) 0)]
         [level (car lookup-result)]
         [index (cadr lookup-result)])
    (list (format "  v~a = get_environment(env, ~a, ~a);\n" variable-id level index)
          variable-id
          increment-context)))

(define (generate-list-statement list-statement context)
  (generate-application list-statement
                        context) ;TODO - it could be "define" or "if", we will deal with them later
  )

(define (generate-arguments arguments prefix index environment-id context)
  (if (null? arguments)
      (cons prefix context)
      (let* ([argument-result (generate-statement (car arguments) context)]
             [argument-code (car argument-result)]
             [argument-rest (cdr argument-result)]
             [argument-variable (car argument-rest)]
             [context (cadr argument-rest)])
        (generate-arguments
         (cdr arguments)
         (string-append
          prefix
          argument-code
          (format "  set_environment(v~a, ~a, v~a);" environment-id index argument-variable)
          "\n")
         (+ index 1)
         environment-id
         context))))

(define (generate-application list-statement context)
  (let* ([list-statement-list (cdr list-statement)]
         [function (car list-statement-list)]
         [arguments (cdr list-statement-list)]
         [function-statement-result (generate-statement function context)]
         [function-code (car function-statement-result)]
         [function-rest (cdr function-statement-result)]
         [function-id (car function-rest)]
         [context (cadr function-rest)]
         [closure-id (fetch-variable-id context)]
         [context (increment-variable-id context)]
         [environment-id (fetch-variable-id context)]
         [context (increment-variable-id context)]
         [arguments-result (generate-arguments arguments "" 0 environment-id context)]
         [argument-code (car arguments-result)]
         [context (cdr arguments-result)]
         [result-id (fetch-variable-id context)]
         [context (increment-variable-id context)])
    (list
     (string-append
      function-code
      (format "  v~a = closure_of(v~a);" closure-id function-id)
      "\n"
      (format "  v~a = create_environment(v~a, ~a);" environment-id closure-id (length arguments))
      "\n"
      argument-code
      (format "  v~a = function_of(v~a)(v~a);" result-id function-id environment-id) ;
      "\n")
     result-id
     context)))

(define (generate-statement statement context)
  ; (displayln (format "[log] generate-statement: statement = ~a" statement))
  (let ([statement-type (car statement)])
    (cond
      [(eq? statement-type 'number-statement) (generate-number-statement statement context)]
      [(eq? statement-type 'bool-statement) (generate-bool-statement statement context)]
      [(eq? statement-type 'symbol-statement) (generate-symbol-statement statement context)]
      [(eq? statement-type 'list-statement) (generate-list-statement statement context)]
      [else (error (format "[log] Error: Unknown statement type ~a" statement-type))])))

(define (generate-statements statements context)
  ; (displayln (format "[log] generate-statements: statements = ~a" statements))
  (if (null? statements)
      (cons empty-string context)
      (let* ([first-statement-pair (generate-statement (car statements) context)]
             [first-statement (car first-statement-pair)]
             [context (car (cdr (cdr first-statement-pair)))]
             [rest-statement-pair (generate-statements (cdr statements) context)]
             [rest-statement (car rest-statement-pair)]
             [context (cdr rest-statement-pair)])
        (cons (string-append first-statement
                             (generate-print-ekans-value-statement (car (cdr first-statement-pair)))
                             generate-collect-statement
                             rest-statement)
              context))))

(define (generate-temp-declarations number-of-variables)
  (if (= number-of-variables 0)
      ""
      (string-append (generate-temp-declarations (- number-of-variables 1))
                     (format "  ekans_value* v~a = NULL;\n  push_stack_slot(&v~a);\n"
                             number-of-variables
                             number-of-variables))))

(define (generate-code parsed-program)
  (let* ([statements (car parsed-program)]
         [statements-pair (generate-statements statements '(1))]
         [statements-code (car statements-pair)]
         [context (cdr statements-pair)]
         [number-of-variables (number-of-variables context)])
    (string-append (generate-temp-declarations number-of-variables)
                   statements-code
                   (format "  pop_stack_slot(~a);\n" number-of-variables))))

(define (generate-main-function parsed-program)
  (let ([code (generate-code parsed-program)]) (string-append prologue code (epilogue))))

(define builtins
  '(("+" "plus") ; ekans_value* plus(ekans_value* environment);
    ("-" "subtract"))) ; ekans_value* subtract(ekans_value* environment);

(define (populate-environment elements index temp-id)
  (if (null? elements)
      ""
      (string-append (format "  v~a = create_closure(*pEnv, ~a);" temp-id (cadr (car elements)))
                     "\n"
                     (format "  set_environment(*pEnv, ~a, v~a);" index temp-id)
                     "\n"
                     (populate-environment (cdr elements) (+ index 1) (+ temp-id 1)))))

(define (generate-build-builtins)
  (string-append "\n"
                 "void build_builtins(ekans_value** pEnv) {"
                 "\n"
                 (format "  *pEnv = create_environment(NULL, ~a);" (length builtins))
                 "\n"
                 (generate-temp-declarations (length builtins))
                 (populate-environment builtins 0 1)
                 (format "  pop_stack_slot(~a);" (length builtins))
                 "\n"
                 "}"
                 "\n"))

(define (generate-build-defines defines)
  (string-append "\n"
                 "void build_defines(ekans_value** pEnv) {"
                 "\n"
                 "  ekans_value* builtins = NULL;"
                 "\n"
                 "  push_stack_slot(&builtins);"
                 "\n"
                 "  build_builtins(&builtins);"
                 "\n"
                 (format "  *pEnv = create_environment(builtins, ~a);" (length defines))
                 "\n"
                 (generate-temp-declarations (length defines))
                 (populate-environment defines 0 1)
                 (format "  pop_stack_slot(~a);" (+ (length defines) 1))
                 "\n"
                 "}"
                 "\n"))

(define (epilogue)
  (string-append
   "}"
   "\n"
   (generate-build-builtins)
   (generate-build-defines '()) ; TODO: this should be the actual functions defined in the program
   (string-append "\n"
                  "int main(int argc, char** argv) {"
                  "\n"
                  "  initialize_ekans();"
                  "\n"
                  "  ekans_value* env = NULL;"
                  "\n"
                  "  build_defines(&env);"
                  "\n"
                  "  f1(env);"
                  "\n"
                  "  finalize_ekans();"
                  "\n"
                  "  return 0;"
                  "\n"
                  "}")))

(define (initial-symbol-table defines)
  (cons (map car defines) (cons (map car builtins) '())))

(define (last-index-of l target current index)
  (if (null? l)
      current
      (let ([head (car l)]
            [rest (cdr l)])
        (if (equal? head target)
            (last-index-of rest target (list index) (+ index 1))
            (last-index-of rest target current (+ index 1))))))

(define (lookup symbol table level)
  (if (null? table)
      '()
      (let ([result (last-index-of (car table) symbol '() 0)])
        (if (null? result)
            (lookup symbol (cdr table) (+ level 1))
            (cons level result)))))

(define (generate-file filename generated-code)
  (with-output-to-file filename (lambda () (write-string generated-code)) #:exists 'replace))
