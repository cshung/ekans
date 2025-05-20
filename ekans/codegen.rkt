; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../common/common.rkt")
(require "context.rkt")
(require "symbols.rkt")

(provide generate-all-code)
(provide generate-file)

;
; This function generates the function prototypes for all generated functions.
; This allow us not to worry about the order of the functions in the file.
;
; It simply generates the code like this:
;
; void f1(ekans_value* env, ekans_value** pReturn);
; void f2(ekans_value* env, ekans_value** pReturn);
; ...
;
(define (generate-function-prototypes function-id)
  (if (= function-id 0)
      empty-string
      (string-append (generate-function-prototypes (- function-id 1))
                     (format "void f~a(ekans_value* env, ekans_value** pReturn);\n" function-id))))

;
; This function generates the prologue for the generated code.
; It includes the ekans.h header file and the function prototypes.
;
(define (prologue number-of-functions)
  (string-append "#include <ekans.h>"
                 "\n"
                 "\n"
                 (generate-function-prototypes number-of-functions)
                 "\n"))

;
; This function generate a call to the collect function.
;
(define generate-collect-statement "  collect();\n")

;
; These functions generate the code for different types of statements.
; They have the same structure:
;
; The main input is a statement, and we also accept a context as input.
;
; The context allows us to let the generation logic know what was the state
; of the whole program (e.g. how many functions, how many variables, etc.)
; as well as letting it report information about how the whole program state
; changes after the statement is generated.
;
; The output is a list of three elements:
; 1. The generated code for the statement
; 2. The variable id that the subsequent code will use to access the value of the statement
; 3. The context after the statement was generated
;

;
; Generating a number statement is trivial and can be used as an example to understand the
; contract. The code obtain a new variable id, use that to store the value of the statement
; and then return the variable id and the updated context.
;
(define (generate-number-statement number-statement context)
  (let ([number-value (cdr number-statement)]
        [variable-id (new-variable-id context)]
        [context (increment-variable-id context)])
    (list (format "  create_number_value(~a, &v~a);\n" number-value variable-id)
          variable-id
          context)))

;
; bool is identical to a number statement, but the value is a boolean.
;
(define (generate-bool-statement bool-statement context)
  (let ([bool-value (cdr bool-statement)]
        [variable-id (new-variable-id context)]
        [context (increment-variable-id context)])
    (list (format "  create_boolean_value(~a, &v~a);\n" (if bool-value "true" "false") variable-id)
          variable-id
          context)))

(define (generate-char-statement char-statement context)
  (let ([char-value (cdr char-statement)]
        [variable-id (new-variable-id context)]
        [context (increment-variable-id context)])
    (list (format "  create_char_value('~a', &v~a);\n" char-value variable-id) variable-id context)))

(define (generate-string-statement string-statement context)
  (let ([string-value (cdr string-statement)]
        [variable-id (new-variable-id context)]
        [context (increment-variable-id context)])
    (list (format "  create_string_value(\"~a\", &v~a);\n" string-value variable-id)
          variable-id
          context)))

;
; A symbol statement means at runtime, this statement will be evaluated to a variable value, and this
; is achieved by mirroring all the available symbols in both the compiler and the runtime.
;
; The compiler maintain a symbol table that records the names of the avaiable values
; At runtime, an identically structured envirnoment will record the values of these symbols.
;
; By computing a path (i.e. the level and index of a symbol in the symbol table), we will use exactly
; the same path to access the value of the symbol in the environment.
;
(define (generate-symbol-statement symbol-statement context)
  (let* ([symbol-value (cdr symbol-statement)]
         [variable-id (new-variable-id context)]
         [context (increment-variable-id context)]
         [lookup-result (lookup symbol-value (symbol-table context) 0)]
         [level (car lookup-result)]
         [index (cadr lookup-result)])
    (list (format "  get_environment(env, ~a, ~a, &v~a);\n" level index variable-id)
          variable-id
          context)))

; if statement
; example: (if #t 1 2)
(define (generate-if-statement if-statement context)
  (let* ([condition (cadr if-statement)] ; condition = #t
         [then-body (caddr if-statement)] ; then-body = 1
         [else-body (cadddr if-statement)] ; else-body = 2
         [result-id (new-variable-id context)] ; result-id = v1
         [context (increment-variable-id context)] ; context = updated-context
         [condition-result
          (generate-statement condition context)] ; condition-result = (code variable updated-context)
         [condition-code
          (car condition-result)] ; condition-code = "create_boolean_value(true, &v2);\n"
         [condition-rest (cdr condition-result)] ; condition-rest = (v2 updated-context)
         [condition-variable (car condition-rest)] ; condition-variable = v2
         [context (cadr condition-rest)] ; context = updated-context
         [then-result (generate-statement then-body context)]
         [then-code (car then-result)] ; then-code = "create_number_value(1, &v3);\n"
         [then-rest (cdr then-result)] ; then-rest = (v3 updated-context)
         [then-variable (car then-rest)] ; then-variable = v3
         [context (cadr then-rest)] ; context = updated-context
         [else-result (generate-statement else-body
                                          context)] ; else-result = (code variable updated-context)
         [else-code (car else-result)] ; else-code = "create_number_value(2, &v4);\n"
         [else-rest (cdr else-result)] ; else-rest = (v4 updated-context)
         [else-variable (car else-rest)] ; else-variable = v4
         [context (cadr else-rest)] ; context = updated-context
         ) ; context = updated-context
    ; (displayln (format "[log] then-code:\n~a" then-code))
    ; (displayln (format "[log] else-code:\n~a" else-code))
    (list (string-append condition-code
                         (format "  if (is_true(v~a)) {\n" condition-variable)
                         (format "  ~a" then-code)
                         (format "    v~a = v~a;\n" result-id then-variable)
                         (format "  } else {\n")
                         (format "  ~a" else-code)
                         (format "    v~a = v~a;\n" result-id else-variable)
                         (format "  }\n"))
          result-id
          context)))

;
; A list statement is simply a list in the source code. It could be a function call, a lambda, and many other things
; that we will handle in the future.
;
; This function simply dispatches the statement to the appropriate function.
;
(define (generate-list-statement list-statement context)
  (let* ([list-statement-list (cdr list-statement)])
    (cond
      [(null? list-statement-list)
       (begin
         (displayln (format "[log] Error: List statement is empty: ~a" list-statement))
         (exit 2))]
      [(and (equal? (caar list-statement-list) 'symbol-statement)
            (equal? (cdar list-statement-list) "lambda"))
       (generate-lambda list-statement-list context)]
      [(and (equal? (caar list-statement-list) 'symbol-statement)
            (equal? (cdar list-statement-list) "let"))
       (generate-let list-statement-list context)]
      [(and (equal? (caar list-statement-list) 'symbol-statement)
            (equal? (cdar list-statement-list) "let*"))
       (generate-let-star list-statement-list context)]
      ; TODO, handle if,and,or
      [(and (equal? (caar list-statement-list) 'symbol-statement)
            (equal? (cdar list-statement-list) "if"))
       (generate-if-statement list-statement-list context)]
      ; we cannot treat them as function - if we do, we will always evaluate all branches, which is not
      ; the way it should be
      [else (generate-application list-statement-list context)])))

;
; A function application is generated as follows:
; 1. Evaluate the expression that will be the function to call
; 2. Create a closure for the function
; 3. Create an environment for the function
; 4. Evaluate the arguments and populate the environment with the argument values
; 5. Call the function with the environment
; 6. Return the result of the function call
;
(define (generate-application list-statement-list context)
  (let* ([function (car list-statement-list)]
         [arguments (cdr list-statement-list)]
         [function-statement-result (generate-statement function context)]
         [function-code (car function-statement-result)]
         [function-rest (cdr function-statement-result)]
         [function-id (car function-rest)]
         [context (cadr function-rest)]
         [closure-id (new-variable-id context)]
         [context (increment-variable-id context)]
         [environment-id (new-variable-id context)]
         [context (increment-variable-id context)]
         [arguments-result (generate-arguments arguments empty-string 0 environment-id context)]
         [argument-code (car arguments-result)]
         [context (cdr arguments-result)]
         [result-id (new-variable-id context)]
         [context (increment-variable-id context)])
    (list
     (string-append
      function-code
      (format "  closure_of(v~a, &v~a);" function-id closure-id)
      "\n"
      (format "  create_environment(v~a, ~a, &v~a);" closure-id (length arguments) environment-id)
      "\n"
      argument-code
      (format "  function_of(v~a)(v~a, &v~a);" function-id environment-id result-id)
      "\n")
     result-id
     context)))

;
; A lambda statement is a function definition. At the point of declaration, it doesn't really
; evaluate the body yet. The right thing to do is simply creating a closure for the function
;
; The key challenge is when we create the closure, we need a C function pointer to the function
; that will be called when the closure is invoked. This function pointer is not available yet.
;
; The solution is to create a pending function by simply allocating a new function id. Now we can
; create a closure for it.
;
; To make sure we will eventually generate the function, we need to enqueue the function
; together with the information necessary to generate the function into a queue hosted in the context.
;
; Then we will ensure that the function is generated when we generate all the functions.
;
; The code works as follows:
; 1. Get the arguments of the lambda as a list of string named arguments-symbols
; 2. Get the function body as a list of statements named function-body
; 3. Create a new function id
; 4. Increment the function id in the context
; 5. Create a new symbol table for the new function by adding the arguments-symbols to the current symbol table
; 6. Create a new context for the new function using the new symbol table
; 7. Enqueue the new function id and the function body into the context
; 8. Create a new variable id for the closure
; 9. Increment the variable id in the context
; 10. Return the code to create the closure, the closure id, and the new context
;
(define (generate-lambda list-statement-list context)
  ; TODO, handle various error cases (e.g. no arguments, argument is not a symbol, etc.)
  (let* ([arguments-list-statement (cadr list-statement-list)]
         [arguments-list (cdr arguments-list-statement)]
         [arguments-symbols (map cdr arguments-list)]
         [function-body (cddr list-statement-list)]
         [new-function-id (new-function-id context)]
         [context (increment-function-id context)]
         [new-symbol-table (cons arguments-symbols (symbol-table context))]
         [new-context (list 0 ; number of variables in new function
                            (number-of-functions context) ; number of functions in the file
                            new-symbol-table
                            '() ; list of pending functions for the new function
                            )]
         [context (enqueue-pending-function new-function-id function-body new-context context)]
         [closure-id (new-variable-id context)]
         [context (increment-variable-id context)])
    (list (format "  create_closure(env, f~a, &v~a);\n" new-function-id closure-id)
          closure-id
          context)))

(define (generate-list-statement-quoted list-statement context)
  (let ([quoted-list-statement (cdr list-statement)]
        [variable-id (new-variable-id context)]
        [context (increment-variable-id context)])
    (if (null? quoted-list-statement)
        (list (format "  create_nil_value(&v~a);\n" variable-id) variable-id context)
        (let* ([first-statement-result (generate-statement-quoted (car quoted-list-statement)
                                                                  context)]
               [first-statement-code (car first-statement-result)]
               [first-statement-rest (cdr first-statement-result)]
               [first-statement-variable (car first-statement-rest)]
               [context (cadr first-statement-rest)]
               [rest-statement-result (generate-list-statement-quoted
                                       (cons 'list-statement (cdr quoted-list-statement))
                                       context)]
               [rest-statement-code (car rest-statement-result)]
               [rest-statement-rest (cdr rest-statement-result)]
               [rest-statement-variable (car rest-statement-rest)]
               [context (cadr rest-statement-rest)]
               [result-id (new-variable-id context)]
               [context (increment-variable-id context)])
          (list (string-append first-statement-code
                               rest-statement-code
                               (format "  create_cons_cell(v~a, v~a, &v~a);\n"
                                       first-statement-variable
                                       rest-statement-variable
                                       result-id))
                result-id
                context)))))

(define (generate-statement-quoted quoted-statement context)
  (let* ([variable-id (new-variable-id context)]
         [context (increment-variable-id context)]
         [quoted-statement-type (car quoted-statement)])
    (cond
      [(eq? quoted-statement-type 'number-statement)
       (list (format "  create_number_value(~a, &v~a);\n" (cdr quoted-statement) variable-id)
             variable-id
             context)]
      [(eq? quoted-statement-type 'bool-statement)
       (list (format "  create_boolean_value(~a, &v~a);\n"
                     (if (cdr quoted-statement) "true" "false")
                     variable-id)
             variable-id
             context)]
      [(eq? quoted-statement-type 'list-statement)
       (generate-list-statement-quoted quoted-statement context)]
      [else (error (format "[log] Error: Unknown statement type ~a" quoted-statement-type))])))
;
; Generate a let statement by transforming it into an application of a lambda function
;
(define (generate-let list-statement-list context)
  (let* ([bindings (cdadr list-statement-list)]
         [symbols (map cadr bindings)]
         [values (map caddr bindings)]
         [body (cddr list-statement-list)]
         [lambda (cons 'list-statement
                       (cons (cons 'symbol-statement "lambda")
                             (cons (cons 'list-statement symbols) body)))]
         [application (cons 'list-statement (cons lambda values))])
    (generate-statement application context)))

;
; Generate a let* statement by transforming it into a series of let statements
;
(define (generate-let-star list-statement-list context)
  (let* ([bindings (cdadr list-statement-list)]
         [body (cddr list-statement-list)])
    (if (null? bindings)
        (generate-statements body context '())
        (let* ([binding-head (car bindings)]
               [binding-tail (cdr bindings)]
               [head-binding (list 'list-statement binding-head)]
               [tail-binding (cons 'list-statement binding-tail)]
               [inner (append (list 'list-statement (cons 'symbol-statement "let*") tail-binding)
                              body)]
               [outer (list 'list-statement (cons 'symbol-statement "let") head-binding inner)])
          (generate-statement outer context)))))

(define (generate-quote-statement quote-statement context)
  (generate-statement-quoted (cdr quote-statement) context))

;
; This function generates the code for any statements, it just dispatches the statement to the appropriate function
;
(define (generate-statement statement context)
  ; (displayln (format "[log] generate-statement: statement = ~a" statement))
  (let ([statement-type (car statement)])
    (cond
      [(eq? statement-type 'number-statement) (generate-number-statement statement context)]
      [(eq? statement-type 'bool-statement) (generate-bool-statement statement context)]
      [(eq? statement-type 'char-statement) (generate-char-statement statement context)]
      [(eq? statement-type 'string-statement) (generate-string-statement statement context)]
      [(eq? statement-type 'symbol-statement) (generate-symbol-statement statement context)]
      [(eq? statement-type 'list-statement) (generate-list-statement statement context)]
      [(eq? statement-type 'quote-statement) (generate-quote-statement statement context)]
      [else (error (format "[log] Error: Unknown statement type ~a" statement-type))])))

;
; This function generates the code for a list of statements.
;
; It assumes there is at least one statement in the list, otherwise
; the concept of result does not make sense, in that case it will just
; return whatever  passed in as the initial result.
;
; and the result of the last statement is the result of the whole list.
;
(define (generate-statements statements context result)
  ; (displayln (format "[log] generate-statements: statements = ~a" statements))
  (if (null? statements)
      (list empty-string result context)
      (let* ([first-statement-result (generate-statement (car statements) context)]
             [first-statement-code (car first-statement-result)]
             [first-statement-rest (cdr first-statement-result)]
             [first-statement-variable (car first-statement-rest)]
             [context (cadr first-statement-rest)]
             [rest-statement-result
              (generate-statements (cdr statements) context first-statement-variable)]
             [rest-statement-code (car rest-statement-result)]
             [rest-statement-rest (cdr rest-statement-result)]
             [rest-statement-variable (car rest-statement-rest)]
             [context (cadr rest-statement-rest)])
        (list (string-append first-statement-code generate-collect-statement rest-statement-code)
              rest-statement-variable
              context))))

;
; At this point, we have done with the various generate-statements functions
;

;
; This is a helper function that generates the code to populate the environment with the arguments
; This is used in the generate-application function.
;
; It simply generates the argument values one by one, and then set the environment with the argument values.;
;
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

;
; This is a helper function that generates the code to declare temporary variables
; This is used in the generate-function function.
;
(define (generate-temp-declarations number-of-variables)
  (if (= number-of-variables 0)
      empty-string
      (string-append (generate-temp-declarations (- number-of-variables 1))
                     (format "  ekans_value* v~a = NULL;\n  push_stack_slot(&v~a);\n"
                             number-of-variables
                             number-of-variables))))

;
; This function generates the code for all the functions by making sure we drain the queue
;
(define (generate-all-functions queue)
  (if (null? queue)
      (cons empty-string 0)
      (let* ([function (car queue)]
             [queue (cdr queue)]
             [function-id (car function)]
             [function-body (cadr function)]
             [function-context (caddr function)]
             [function-result (generate-function function-id function-body function-context)]
             [function-code (car function-result)]
             [function-context (cdr function-result)]
             [queue (append queue (pending-functions function-context))]
             [rest-result (generate-all-functions queue)]
             [rest-code (car rest-result)]
             [rest-count (cdr rest-result)])
        (cons (string-append function-code rest-code) (+ rest-count 1)))))

;
; This function generates the code for a single function.
; It starts with generating all the variable declarations, then generates the code for the statements,
; and finally generates the code to return the result of the function.
;
(define (generate-function function-id statements context)
  (let* ([statements-result (generate-statements statements context '())]
         [statements-code (car statements-result)]
         [statements-variable (cadr statements-result)]
         [context (caddr statements-result)]
         [number-of-variables (number-of-variables context)])
    (cons (string-append (format "void f~a(ekans_value* env, ekans_value** pReturn) " function-id)
                         lb
                         "\n"
                         (generate-temp-declarations number-of-variables)
                         statements-code
                         (format "  *pReturn = v~a;" statements-variable)
                         "\n"
                         (format "  pop_stack_slot(~a);" number-of-variables)
                         "\n"
                         rb
                         "\n")
          context)))

;
; This function generates everything for the whole program
; It starts with the prologue, then generates all the functions, and finally generates the epilogue.
;
(define (generate-all-code statements)
  (let* ([initial-queue (list (list 1 statements (initial-context '())))]
         [all-function-result (generate-all-functions initial-queue)]
         [all-function-code (car all-function-result)]
         [all-function-count (cdr all-function-result)])
    (string-append (prologue all-function-count) all-function-code (epilogue))))

;
; This helper function generates the code to populate the environment with the elements
; This is used in the generate-build-defines and generate-build-builtins functions.
;
(define (populate-environment elements index temp-id)
  (if (null? elements)
      empty-string
      (string-append (format "  create_closure(*pEnv, ~a, &v~a);" (cadr (car elements)) temp-id)
                     "\n"
                     (format "  set_environment(*pEnv, ~a, v~a);" index temp-id)
                     "\n"
                     (populate-environment (cdr elements) (+ index 1) (+ temp-id 1)))))

;
; This function generates the code to build the environment for the builtins at runtime.
;
(define (generate-build-builtins)
  (string-append "\n"
                 "void build_builtins(ekans_value** pEnv) "
                 lb
                 "\n"
                 (format "  create_environment(NULL, ~a, pEnv);" (length builtins))
                 "\n"
                 (generate-temp-declarations (length builtins))
                 (populate-environment builtins 0 1)
                 (format "  pop_stack_slot(~a);" (length builtins))
                 "\n"
                 rb
                 "\n"))

;
; This function generates the code to build the environment for the defines at runtime.
; It is similar to the generate-build-builtins function, but it uses the defines instead of the builtins.
; The defines are passed as an argument to the function.
;
(define (generate-build-defines defines)
  (string-append "\n"
                 "void build_defines(ekans_value** pEnv) "
                 lb
                 "\n"
                 "  ekans_value* builtins = NULL;"
                 "\n"
                 "  push_stack_slot(&builtins);"
                 "\n"
                 "  build_builtins(&builtins);"
                 "\n"
                 (format "  create_environment(builtins, ~a, pEnv);" (length defines))
                 "\n"
                 (generate-temp-declarations (length defines))
                 (populate-environment defines 0 1)
                 (format "  pop_stack_slot(~a);" (+ (length defines) 1))
                 "\n"
                 rb
                 "\n"))

;
; This function generates the epilogue for the generated code.
; It includes the code to initialize and finalize the ekans runtime, and the main function.
; The main function initializes the ekans runtime, creates an environment, and calls the build_defines function.
; It also calls the f1 function with the environment and prints the result.
;
(define (epilogue)
  (string-append
   (generate-build-builtins)
   (generate-build-defines '()) ; TODO: this should be the actual functions defined in the program
   (string-append "\n"
                  "int main(int argc, char** argv) "
                  lb
                  "\n"
                  "  initialize_ekans();"
                  "\n"
                  "  ekans_value* env = NULL;"
                  "\n"
                  "  push_stack_slot(&env);"
                  "\n"
                  "  ekans_value* v1 = NULL;"
                  "\n"
                  "  push_stack_slot(&v1);"
                  "\n"
                  "  build_defines(&env);"
                  "\n"
                  "  f1(env, &v1);"
                  "\n"
                  "  print_ekans_value(v1);"
                  "\n"
                  "  pop_stack_slot(2);"
                  "\n"
                  "  finalize_ekans();"
                  "\n"
                  "  return 0;"
                  "\n"
                  rb
                  "\n")))

;
; This function generates the initial context for the program.
; It initializes the number of variables and functions to 0, and creates an symbol table corresponding to the defines and builtins.
; This makes sure the symbol table is always in sync with the runtime environment.
;
(define (initial-context defines)
  (list 0 ; number of variables
        1 ; number of functions
        (initial-symbol-table defines)
        '() ; list of pending functions to generate
        ))

;
; Save the output to a file
;
(define (generate-file filename generated-code)
  (with-output-to-file filename (lambda () (write-string generated-code)) #:exists 'replace))
