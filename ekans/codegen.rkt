; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../common/common.rkt")
(require "context.rkt")
(require "symbols.rkt")

(provide generate-all-code)
(provide generate-file)

;
; Turn this on to show the symbol tables as comments in the generated code
; This is useful to debug the symbol table generation
;
(define show-comment #t)

;
; Turn this on to generate a collect statement after each statement
; This is useful to stress test the garbage collector
;
(define gc-stress #f)

(define (optional-comment comment)
  (if show-comment comment ""))

(define (optional-collect)
  (if gc-stress
      (generate-collect-statement)
      ""))

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
(define (generate-collect-statement)
  "  collect();\n")

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
    (list (string-append (format "  create_number_value(~a, &v~a);\n" number-value variable-id)
                         (optional-collect))
          variable-id
          context)))

;
; bool is identical to a number statement, but the value is a boolean.
;
(define (generate-bool-statement bool-statement context)
  (let ([bool-value (cdr bool-statement)]
        [variable-id (new-variable-id context)]
        [context (increment-variable-id context)])
    (list (string-append
           (format "  create_boolean_value(~a, &v~a);\n" (if bool-value "true" "false") variable-id)
           (optional-collect))
          variable-id
          context)))

(define (generate-char-statement char-statement context)
  (let ([char-value (cdr char-statement)]
        [variable-id (new-variable-id context)]
        [context (increment-variable-id context)])
    (list
     (string-append
      (cond
        [(equal? char-value #\newline) (format "  create_char_value('\\n', &v~a);\n" variable-id)]
        [else (format "  create_char_value('~a', &v~a);\n" char-value variable-id)])
      (optional-collect))
     variable-id
     context)))

(define (generate-string-statement string-statement context)
  (let ([string-value (cdr string-statement)]
        [variable-id (new-variable-id context)]
        [context (increment-variable-id context)])
    (list (string-append (format "  create_string_value(\"~a\", &v~a);\n" string-value variable-id)
                         (optional-collect))
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
    (list (string-append (optional-comment (format "  // looking up the value for ~a\n" symbol-value))
                         (format "  get_environment(env, ~a, ~a, &v~a);\n" level index variable-id)
                         (optional-collect))
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
                         (optional-collect)
                         (format "  } else {\n")
                         (format "  ~a" else-code)
                         (format "    v~a = v~a;\n" result-id else-variable)
                         (optional-collect)
                         (format "  }\n")
                         (optional-collect))
          result-id
          context)))

; and statement
(define (generate-and-statement and-statement context)
  (let ([head (car and-statement)] ; head = (symbol-statement . "and")
        [arguments (cdr and-statement)] ; arguments = (#b1 #b2 #b3)
        )
    (if (null? arguments)
        (generate-bool-statement (cons 'bool-statement #t) context)
        (let* ([first-argument (car arguments)] ; first-argument = #b1
               [rest-arguments (cdr arguments)] ; rest-arguments = (#b2 #b3)
               [if-statement (list 'list-statement
                                   (cons 'symbol-statement "if")
                                   first-argument
                                   (cons 'list-statement (cons head rest-arguments))
                                   (cons 'bool-statement
                                         #f))] ; if-statement = (if #b1 (and #b2 #b3) #f)
               )
          (generate-statement if-statement context)))))

; or statement
(define (generate-or-statement or-statement context)
  (let ([head (car or-statement)] ; head = (symbol-statement . "or")
        [arguments (cdr or-statement)] ; arguments = (#b1 #b2 #b3)
        )
    (if (null? arguments)
        (generate-bool-statement (cons 'bool-statement #f) context)
        (let* ([first-argument (car arguments)] ; first-argument = #b1
               [rest-arguments (cdr arguments)] ; rest-arguments = (#b2 #b3)
               [if-statement
                (list 'list-statement
                      (cons 'symbol-statement "if")
                      first-argument
                      (cons 'bool-statement #t)
                      (cons 'list-statement
                            (cons head rest-arguments)))] ; if-statement = (if #b1 (or #b2 #b3) #f)
               )
          (generate-statement if-statement context)))))

; cond statement
(define (generate-cond-statement cond-statement context)
  (if (> (length cond-statement) 2)
      (let* ([head (car cond-statement)]
             [result-id (new-variable-id context)] ; result-id = v1
             [context (increment-variable-id context)] ; context = updated-context
             [first-branch (cadr cond-statement)]
             [first-condition (cadr first-branch)]
             [first-branch-logic (cddr first-branch)]
             [first-condition-result (generate-statement first-condition context)]
             [first-condition-code (car first-condition-result)]
             [first-condition-var (cadr first-condition-result)]
             [context (caddr first-condition-result)]
             [first-branch-logic-result (generate-statements first-branch-logic context '())]
             [first-branch-logic-code (car first-branch-logic-result)]
             [first-branch-logic-var (cadr first-branch-logic-result)]
             [context (caddr first-branch-logic-result)]
             [else-logic (cons head (cddr cond-statement))]
             [else-logic-result (generate-cond-statement else-logic context)]
             [else-logic-code (car else-logic-result)]
             [else-logic-var (cadr else-logic-result)]
             [context (caddr else-logic-result)])
        (list (string-append first-condition-code
                             (format "  if (is_true(v~a)) {\n" first-condition-var)
                             first-branch-logic-code
                             (format "    v~a = v~a;\n" result-id first-branch-logic-var)
                             "  } else {\n"
                             else-logic-code
                             (format "    v~a = v~a;\n" result-id else-logic-var)
                             "  }\n")
              result-id
              context))
      (generate-statements (cddadr cond-statement) context '())))

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
      [(and (equal? (caar list-statement-list) 'symbol-statement)
            (equal? (cdar list-statement-list) "if"))
       (generate-if-statement list-statement-list context)]
      [(and (equal? (caar list-statement-list) 'symbol-statement)
            (equal? (cdar list-statement-list) "and"))
       (generate-and-statement list-statement-list context)]
      [(and (equal? (caar list-statement-list) 'symbol-statement)
            (equal? (cdar list-statement-list) "or"))
       (generate-or-statement list-statement-list context)]
      [(and (equal? (caar list-statement-list) 'symbol-statement)
            (equal? (cdar list-statement-list) "cond"))
       (generate-cond-statement list-statement-list context)]
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
      (format "  closure_of(v~a, &v~a);\n" function-id closure-id)
      (optional-collect)
      (optional-comment (format "  // preparing environment with ~a slots for call\n"
                                (length arguments)))
      (format "  create_environment(v~a, ~a, &v~a);\n" closure-id (length arguments) environment-id)
      (optional-collect)
      argument-code
      (format "  function_of(v~a)(v~a, &v~a);\n" function-id environment-id result-id)
      (optional-collect))
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
         [context (enqueue-pending-function new-function-id function-body new-symbol-table context)]
         [closure-id (new-variable-id context)]
         [context (increment-variable-id context)])
    (list (string-append (format "  create_closure(env, f~a, &v~a);\n" new-function-id closure-id)
                         (optional-collect))
          closure-id
          context)))

(define (generate-list-statement-quoted list-statement context)
  (let ([quoted-list-statement (cdr list-statement)]
        [variable-id (new-variable-id context)]
        [context (increment-variable-id context)])
    (if (null? quoted-list-statement)
        (list (string-append (format "  create_nil_value(&v~a);\n" variable-id) (optional-collect))
              variable-id
              context)
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
                                       result-id)
                               (optional-collect))
                result-id
                context)))))

(define (generate-statement-quoted quoted-statement context)
  (let* ([variable-id (new-variable-id context)]
         [context (increment-variable-id context)]
         [quoted-statement-type (car quoted-statement)])
    (cond
      [(eq? quoted-statement-type 'number-statement)
       (list (string-append
              (format "  create_number_value(~a, &v~a);\n" (cdr quoted-statement) variable-id)
              (optional-collect))
             variable-id
             context)]
      [(eq? quoted-statement-type 'bool-statement)
       (list (string-append (format "  create_boolean_value(~a, &v~a);\n"
                                    (if (cdr quoted-statement) "true" "false")
                                    variable-id)
                            (optional-collect))
             variable-id
             context)]
      [(eq? quoted-statement-type 'char-statement)
       (list
        (string-append
         (cond
           [(equal? (cdr quoted-statement) #\newline)
            (format "  create_char_value('\\n', &v~a);\n" variable-id)]
           [else (format "  create_char_value('~a', &v~a);\n" (cdr quoted-statement) variable-id)])
         (optional-collect))
        variable-id
        context)]
      [(eq? quoted-statement-type 'list-statement)
       (generate-list-statement-quoted quoted-statement context)]
      [(eq? quoted-statement-type 'symbol-statement)
       (list (string-append
              (format "  create_symbol_value(\"~a\", &v~a);\n" (cdr quoted-statement) variable-id)
              (optional-collect))
             variable-id
             context)]
      [else (error (format "[log] Error: Unknown quoted statement type ~a" quoted-statement-type))])))
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
      [(eq? statement-type 'set-environment) (generate-set-environment-statement statement context)]
      [else (error (format "[log] Error: Unknown statement type ~a" statement-type))])))

(define (generate-set-environment-statement statement context)
  (let* ([expression (cadr statement)]
         [index (caddr statement)]
         [expression-result (generate-statement expression context)]
         [expression-code (car expression-result)]
         [expression-rest (cdr expression-result)]
         [expression-var (car expression-rest)]
         [expression-code
          (string-append expression-code
                         (format "  set_environment(env, ~a, v~a);\n" index expression-var)
                         (optional-collect))]
         [expression-result (cons expression-code expression-rest)])
    expression-result))

(define (set-environment values counter)
  (if (null? values)
      '()
      (cons (list 'set-environment (car values) counter)
            (set-environment (cdr values) (+ counter 1)))))

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
      (let ([defines (extract-defines statements)])
        (if (null? (car defines))
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
              (list (string-append first-statement-code rest-statement-code)
                    rest-statement-variable
                    context))
            (let* ([define-names (car defines)]
                   [define-values (cdr defines)]
                   [context (push-symbols define-names context)]
                   [environment-id (new-variable-id context)]
                   [context (increment-variable-id context)]
                   [define-result
                    (generate-statements (set-environment define-values 0) context result)]
                   [define-code (car define-result)]
                   [context (caddr define-result)]
                   [generate-statements-result
                    (generate-statements (filter not-define? statements) context result)]
                   [generate-statements-code (car generate-statements-result)]
                   [generate-statements-rest (cdr generate-statements-result)]
                   [generate-statements-result
                    (cons (string-append
                           (optional-comment (format "/* Adding defines here:\n~a*/\n"
                                                     (pretty-symbol-table (symbol-table context))))
                           (format "  create_environment(env, ~a, &v~a);\n  env = v~a;\n"
                                   (length define-names)
                                   environment-id
                                   environment-id)
                           (optional-collect)
                           define-code
                           generate-statements-code)
                          generate-statements-rest)])
              generate-statements-result)))))

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
          (format "  set_environment(v~a, ~a, v~a);\n" environment-id index argument-variable)
          (optional-collect))
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
                     (format "  ekans_value* v~a = NULL;\n" number-of-variables)
                     (optional-collect)
                     (format "  push_stack_slot(&v~a);\n" number-of-variables)
                     (optional-collect))))

;
; This function generates the code for all the functions by making sure we drain the queue
;
(define (generate-all-functions context)
  (if (null? (pending-functions context))
      (cons empty-string 0)
      (let* ([queue (pending-functions context)]
             [function (car queue)]
             [queue (cdr queue)]
             [function-id (car function)]
             [function-body (cadr function)]
             [function-symbol-table (caddr function)]
             [function-context (list 0 ; number of variables
                                     (number-of-functions context) ; number of functions
                                     function-symbol-table ; symbol table
                                     '())]
             [function-result (generate-function function-id function-body function-context)]
             [function-code (car function-result)]
             [function-context (cdr function-result)]
             ; Reverse the list because `cons` enqueues functions in reverse order, ensuring correct queue order.
             [queue (append queue (reverse (pending-functions function-context)))]
             [function-context (list 0 ; number of variables
                                     (number-of-functions function-context) ; number of functions
                                     '() ; symbol table
                                     queue)]
             [rest-result (generate-all-functions function-context)]
             [rest-code (car rest-result)]
             [rest-count (cdr rest-result)])
        (cons (string-append function-code rest-code) (+ rest-count 1)))))

(define (pretty-symbol-table table)
  (if (null? table)
      ""
      (format "~a\n~a" (car table) (pretty-symbol-table (cdr table)))))

;
; This function generates the code for a single function.
; It starts with generating all the variable declarations, then generates the code for the statements,
; and finally generates the code to return the result of the function.
;
(define (generate-function function-id statements context)
  (let* ([original-context context]
         [statements-result (generate-statements statements context '())]
         [statements-code (car statements-result)]
         [statements-variable (cadr statements-result)]
         [context (caddr statements-result)]
         [number-of-variables (number-of-variables context)])
    (cons
     (string-append (optional-comment (format "/*\nThe symbol table for this function is:\n~a\n"
                                              (pretty-symbol-table (symbol-table original-context))))
                    (optional-comment (format "The body for this function is:\n~a\n*/\n" statements))
                    (format "void f~a(ekans_value* env, ekans_value** pReturn) " function-id)
                    lb
                    "\n"
                    (generate-temp-declarations number-of-variables)
                    statements-code
                    (format "  *pReturn = v~a;\n" statements-variable)
                    (format "  pop_stack_slot(~a);\n" number-of-variables)
                    (generate-collect-statement)
                    rb
                    "\n")
     context)))

(define (define? statement)
  (and ;
   (equal? (car statement) 'list-statement)
   (equal? (caadr statement) 'symbol-statement)
   (equal? (cdadr statement) "define")))

(define (not-define? statement)
  (not (define? statement)))

(define (define-name statement)
  (let ([third (caddr statement)])
    (if (equal? (car third) 'symbol-statement)
        (cdr third)
        (cdadr third))))

(define (define-value statement)
  (let ([third (caddr statement)]
        [tail (cdddr statement)])
    (if (equal? (car third) 'symbol-statement)
        (car tail)
        (append
         (list 'list-statement (cons 'symbol-statement "lambda") (cons 'list_statement (cddr third)))
         tail))))

(define (extract-defines statements)
  (let* ([defines (filter define? statements)]
         [names (map define-name defines)]
         [values (map define-value defines)])
    (cons names values)))

;
; This function generates everything for the whole program
; It starts with the prologue, then generates all the functions, and finally generates the epilogue.
;
(define (generate-all-code statements)
  (let* ([initial-context (list 0 ; number of variables
                                1 ; number of functions
                                '() ; symbol table
                                (list (list 1 statements (initial-symbol-table))) ; pending functions
                                )]
         [all-function-result (generate-all-functions initial-context)]
         [all-function-code (car all-function-result)]
         [all-function-count (cdr all-function-result)])
    (string-append (prologue all-function-count) all-function-code (epilogue))))

;
; This helper function generates the code to populate the environment with the elements
; This is used in the generate-build-builtins functions.
;
(define (populate-environment elements index temp-id)
  (if (null? elements)
      empty-string
      (string-append (format "  create_closure(*pEnv, ~a, &v~a);\n" (cadr (car elements)) temp-id)
                     (format "  set_environment(*pEnv, ~a, v~a);\n" index temp-id)
                     (populate-environment (cdr elements) (+ index 1) (+ temp-id 1)))))

;
; This function generates the code to build the environment for the builtins at runtime.
;
(define (generate-build-builtins)
  (string-append "\n"
                 "void build_builtins(ekans_value** pEnv) "
                 lb
                 "\n"
                 (format "  create_environment(NULL, ~a, pEnv);\n" (length builtins))
                 (generate-temp-declarations (length builtins))
                 (populate-environment builtins 0 1)
                 (format "  pop_stack_slot(~a);\n" (length builtins))
                 rb
                 "\n"))

;
; This function generates the epilogue for the generated code.
; It includes the code to initialize and finalize the ekans runtime, and the main function.
; The main function initializes the ekans runtime, creates an environment, and calls the build_builtins function.
; It also calls the f1 function with the environment and prints the result.
;
(define (epilogue)
  (string-append (generate-build-builtins)
                 (string-append "int main(int argc, char** argv) "
                                lb
                                "\n"
                                "  initialize_ekans();\n"
                                "  ekans_value* env = NULL;\n"
                                "  push_stack_slot(&env);\n"
                                "  ekans_value* v1 = NULL;\n"
                                "  push_stack_slot(&v1);\n"
                                "  build_builtins(&env);\n"
                                "  f1(env, &v1);\n"
                                "  print_ekans_value(v1);\n"
                                "  pop_stack_slot(2);\n"
                                "  finalize_ekans();\n"
                                "  return 0;\n"
                                rb
                                "\n")))

;
; Save the output to a file
;
(define (generate-file filename generated-code)
  (with-output-to-file filename (lambda () (write-string generated-code)) #:exists 'replace))
