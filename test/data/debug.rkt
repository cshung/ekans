; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.







(define library
  "(define (map f lst) (if (null? lst) '() (cons (f (car lst)) (map f (cdr lst))))) (define (length lst) (if (null? lst) 0 (+ 1 (length (cdr lst)))))(define args (get-args))(define (filter pred lst)(cond[(null? lst) '()][(pred (car lst)) (cons (car lst) (filter pred (cdr lst)))][else (filter pred (cdr lst))]))(define (append lst1 lst2)(if (null? lst1)lst2(cons (car lst1) (append (cdr lst1) lst2))))(define (reverse lst)(define (helper lst acc)(if (null? lst)acc(helper (cdr lst) (cons (car lst) acc))))(helper lst '()))")

(define (compiler input-file output-file)
  (define input (string-append library (read-file input-file)))
  (define parsed-program (parse-statements (string->list input)))
  (if (eq? parsed-program 'error)
      (displayln "Error: Unable to parse the input.")
      (let ([generated-code (generate-all-code (car parsed-program))])
        (write-file output-file generated-code))))

(define (main)
  (if (< (length args) 2)
      (displayln "Usage: ./compiler.out input.rkt output.c")
      (compiler (car args) (cadr args))))



(main)
; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.



(define lp #\()
(define rp #\))
(define lb "{")
(define rb "}")
(define ls #\[)
(define rs #\])
(define empty-string "")








; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.









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
        [(equal? char-value #\') (format "  create_char_value('\\'', &v~a);\n" variable-id)]
        [(equal? char-value #\\) (format "  create_char_value('\\\\', &v~a);\n" variable-id)]
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
       (generate-number-statement quoted-statement context)]
      [(eq? quoted-statement-type 'bool-statement) (generate-bool-statement quoted-statement context)]
      [(eq? quoted-statement-type 'char-statement) (generate-char-statement quoted-statement context)]
      [(eq? quoted-statement-type 'string-statement)
       (generate-string-statement quoted-statement context)]
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
                           (optional-comment (format "// Adding defines here:\n~a"
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
      (format "// ~a\n~a" (car table) (pretty-symbol-table (cdr table)))))

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
    (cons (string-append
           (optional-comment (format "// The symbol table for this function is:\n~a\n"
                                     (pretty-symbol-table (symbol-table original-context))))
           ; (optional-comment (format "// The body for this function is:\n//~a\n\n" statements))
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
                                "  initialize_ekans(argc, argv);\n"
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
; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.














(define (new-variable-id context)
  (+ (car context) 1))

(define (number-of-variables context)
  (car context))

(define (increment-variable-id context)
  (cons (+ (car context) 1) (cdr context)))

(define (new-function-id context)
  (+ (cadr context) 1))

(define (number-of-functions context)
  (cadr context))

(define (increment-function-id context)
  (cons (car context) (cons (+ (cadr context) 1) (cddr context))))

(define (symbol-table context)
  (caddr context))

(define (push-symbols symbols context)
  (list (car context) ; variable unchanged
        (cadr context) ; num function unchanged
        (cons symbols (caddr context)) ; pushing the symbols into the symbol table
        (cadddr context) ; pending functions unchanged
        ))

(define (enqueue-pending-function id body function-context context)
  (list (car context) ; variable unchanged
        (cadr context) ; num function unchanged
        (caddr context) ; symbol table unchanged
        (cons (list id body function-context) (cadddr context))))

(define (pending-functions context)
  (cadddr context))
; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.







(define (digit? c)
  (and (char>=? c #\0) (char<=? c #\9)))

(define (take-while input condition)
  (if (null? input)
      (cons '() '())
      (let ([decision (condition input)])
        (cond
          [(equal? decision 'keep-going)
           (let* ([result (take-while (cdr input) condition)]
                  [result-value (car result)]
                  [result-tail (cdr result)])
             (cons (cons (car input) result-value) result-tail))]
          [(equal? decision 'drop-and-stop) (cons '() input)]
          [(equal? decision 'take-and-stop) (cons (cons (car input) '()) (cdr input))]
          [else (error "Unknown decision" decision)]))))

(define (digit-decision input)
  (if (digit? (car input)) 'keep-going 'drop-and-stop))

(define (symbol-decision input)
  (if (token-end? input) 'drop-and-stop 'keep-going))

(define (string-decision input)
  (if (and (not (equal? (car input) #\\)) (equal? (cadr input) #\")) 'take-and-stop 'keep-going))

(define (digits-to-number lst acc)
  (if (null? lst)
      acc
      (let ([digit (char->integer (car lst))])
        (digits-to-number (cdr lst) (+ (* acc 10) (- digit (char->integer #\0)))))))

(define (token-end? suffix)
  (or (null? suffix) (member (car suffix) '(#\space #\newline #\( #\) #\[ #\]))))

(define (skip-comment input)
  (cond
    [(null? input) '()]
    [(equal? (car input) #\newline) (cdr input)]
    [else (skip-comment (cdr input))]))

;
; match
;
; input  - a list of characters representing the text to be tokenized
; prefix - a list of characters representing the prefix to be matched
; output - a list of 1 element where the first element is the remaining input
;          otherwise, it returns an empty list
;
(define (match input
          prefix)
  (if (null? prefix)
      (list input)
      (if (null? input)
          '()
          (if (equal? (car input) (car prefix))
              (match (cdr input)
                [cdr prefix])
              '()))))

;
; lexer-keywords
;
; input    - a list of characters representing the text to be tokenized
; keywords - a list of (keyword, token-type) pairs representing the keywords to be matched
; output   - a pair of a token and the rest of the text to be tokenized as a list of characters
;            a token is represented as a pair of token type and the token value, which is '() in case of a keyword
;            or '() in case of a keyword not found
;
(define (lexer-keywords input keywords)
  (if (null? keywords)
      '()
      (let* ([keyword-pair (car keywords)]
             [keyword (car keyword-pair)]
             [token (cdr keyword-pair)]
             [match-result (match input
                             keyword)])
        (if (and (not (null? match-result)) (token-end? (car match-result)))
            (cons token (car match-result))
            (lexer-keywords input (cdr keywords))))))

(define keywords
  (list (cons (string->list "#t") (cons 'bool #t))
        (cons (string->list "#f") (cons 'bool #f))
        (cons (string->list "#\\newline") (cons 'character #\newline))
        (cons (string->list "#\\space") (cons 'character #\space))))

;
; lexer
;
; input  - a list of characters representing the text to be tokenized
; output - a pair of a token and the rest of the text to be tokenized as a list of characters
;          a token is represented as a pair of token type and the token value
;
; error  - in case the stream is invalid, it will be terminated right away with a token of type unknown
;
(define (lexer input)
  (if (null? input)
      (cons (cons 'eof '()) '())
      (let ([lexer-keywords-result (lexer-keywords input keywords)])
        (if (not (null? lexer-keywords-result))
            lexer-keywords-result
            (let ([peek (car input)])
              (cond
                ; Comments
                [(equal? peek #\;) (lexer (skip-comment (cdr input)))]
                ; Whitespace
                [(equal? peek #\space) (lexer (cdr input))]
                [(equal? peek #\newline) (lexer (cdr input))]
                ; Delimiters
                [(equal? peek lp) (cons (cons 'lparen '()) (cdr input))]
                [(equal? peek rp) (cons (cons 'rparen '()) (cdr input))]
                [(equal? peek ls) (cons (cons 'lparen '()) (cdr input))]
                [(equal? peek rs) (cons (cons 'rparen '()) (cdr input))]
                ; Quote
                [(equal? peek #\') (cons (cons 'quote '()) (cdr input))]
                ; Character
                [(and (pair? (cdr input)) (equal? peek #\#) (equal? (cadr input) #\\))
                 (cond
                   ; case: alphabet
                   [(pair? (cddr input)) (cons (cons 'character (caddr input)) (cdddr input))]
                   ; case: unknown
                   [else (cons (cons 'unknown '()) '())])]
                ; Number
                [(digit? peek)
                 (let ([number-result (take-while input digit-decision)])
                   (if (token-end? (cdr number-result))
                       (cons (cons 'number (digits-to-number (car number-result) 0))
                             (cdr number-result))
                       (cons (cons 'unknown '()) '())))]
                ; String
                [(equal? peek #\")
                 (let ([string-result (take-while input string-decision)])
                   (if (token-end? (cddr string-result))
                       (cons (cons 'string (list->string (cdar string-result))) (cddr string-result))
                       (cons (cons 'unknown '()) '())))]
                ; Symbol
                [else
                 (let* ([symbol-result (take-while input symbol-decision)]
                        [symbol (car symbol-result)]
                        [symbol-value (list->string symbol)]
                        [tail (cdr symbol-result)])
                   (cons (cons 'symbol symbol-value) tail))]))))))
; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.








;
; Grammar
;
; The current restricted language can only deal with a sequence of statement
; where each statement is just a number, boolean or list. This is meant to be expanded.
;
; prog = statements
; statements = epsilon | statement statements
; statement = number | bool | list | symbol | quote statement
;

;
; parse-statements
;
; input  - the text to be parsed
; output - a list of statements and the rest of the text to be parsed
;
; error  - in case the token with the rest of the text cannot be interpreted
;          as a statement, 'error will be returned
;
(define (parse-statements input)
  (let* ([first-lex (lexer input)]
         [first-token (car first-lex)]
         [first-rest (cdr first-lex)]
         [first-token-type (car first-token)])
    (cond
      [(eq? first-token-type 'eof) (cons '() '())]
      [else
       (let ([parse1 (parse-statement input)])
         (if (eq? parse1 'error)
             'error
             (let* ([first-statement (car parse1)]
                    [first-rest (cdr parse1)]
                    [parse2 (parse-statements first-rest)])
               (if (eq? parse2 'error)
                   'error
                   (let ([next-statements (car parse2)]
                         [last-rest (cdr parse2)])
                     (cons (cons first-statement next-statements) last-rest))))))])))

;
; parse-statement
;
; input  - the text to be parsed
; output - a statement and the rest of the text to be parsed
;
; error  - in case the token with the rest of the text cannot be interpreted
;          as a statement, 'error will be returned
;
(define (parse-statement input)
  (let* ([first-lex (lexer input)]
         [first-token (car first-lex)]
         [first-rest (cdr first-lex)]
         [first-token-type (car first-token)])
    (cond
      [(eq? first-token-type 'number) (cons (cons 'number-statement (cdr first-token)) first-rest)]
      [(eq? first-token-type 'bool) (cons (cons 'bool-statement (cdr first-token)) first-rest)]
      [(eq? first-token-type 'character) (cons (cons 'char-statement (cdr first-token)) first-rest)]
      [(eq? first-token-type 'symbol) (cons (cons 'symbol-statement (cdr first-token)) first-rest)]
      [(eq? first-token-type 'string) (cons (cons 'string-statement (cdr first-token)) first-rest)]
      [(eq? first-token-type 'lparen) (parse-list-statement input)]
      [(eq? first-token-type 'quote) (parse-quote-statement input)]
      [else 'error])))

;
; parse-quote-statement
;
; input  - the text to be parsed
; output - a quote statement and the rest of the text to be parsed
;
; error  - in case the token with the rest of the text cannot be interpreted
;          as a statement, 'error will be returned
;
(define (parse-quote-statement input)
  (let* ([first-lex (lexer input)]
         [first-token (car first-lex)]
         [first-rest (cdr first-lex)]
         [first-token-type (car first-token)])
    (if (eq? first-token-type 'quote)
        (let* ([parse1 (parse-statement first-rest)])
          (if (eq? parse1 'error)
              'error
              (cons (cons 'quote-statement (car parse1)) (cdr parse1))))
        'error)))

;
; parse-list-statement
;
; input  - the text to be parsed
; output - a list statement and the rest of the text to be parsed
;
; error  - in case the token with the rest of the text cannot be interpreted
;          as a statement, 'error will be returned
;
(define (parse-list-statement input)
  (let* ([first-lex (lexer input)]
         [first-token (car first-lex)]
         [first-rest (cdr first-lex)]
         [first-token-type (car first-token)])
    (if (eq? first-token-type 'lparen)
        (let* ([parse1 (parse-list-end first-rest)])
          (if (eq? parse1 'error)
              'error
              (cons (cons 'list-statement (car parse1)) (cdr parse1))))
        'error)))

;
; parse-list-end
;
; input  - the text to be parsed with the initial lp token skipped
; output - a list of statements and the rest of the text to be parsed
;
; error  - in case the token with the rest of the text cannot be interpreted
;          as a statement, 'error will be returned
;
(define (parse-list-end input)
  (let* ([first-lex (lexer input)]
         [first-token (car first-lex)]
         [first-rest (cdr first-lex)]
         [first-token-type (car first-token)])
    (cond
      [(eq? first-token-type 'eof) 'error]
      [(eq? first-token-type 'rparen) (cons '() first-rest)]
      [else
       (let ([parse1 (parse-statement input)])
         (if (eq? parse1 'error)
             'error
             (let* ([first-statement (car parse1)]
                    [first-rest (cdr parse1)]
                    [parse2 (parse-list-end first-rest)])
               (if (eq? parse2 'error)
                   'error
                   (let ([next-statements (car parse2)]
                         [last-rest (cdr parse2)])
                     (cons (cons first-statement next-statements) last-rest))))))])))
; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.








(define builtins
  '(("+" "plus") ("-" "subtract")
                 ("*" "multiply")
                 ("/" "division")
                 ("not" "not")
                 ("char<=?" "char_le")
                 ("char>=?" "char_ge")
                 ("cons" "list_cons")
                 ("list" "list_constructor")
                 ("=" "equals")
                 ("eq?" "equals")
                 ("equal?" "equals")
                 ("null?" "is_null")
                 ("member" "member")
                 ("car" "car")
                 ("cdr" "cdr")
                 ("char->integer" "char_to_int")
                 ("string->list" "string_to_list")
                 ("get-args" "args")
                 ("displayln" "println")
                 ("<" "less")
                 (">" "greater")
                 ("error" "failfast")
                 ("pair?" "is_pair")
                 ;
                 ; Begin TODO
                 ;
                 ("list->string" "char_to_int")
                 ("string-append" "char_to_int")
                 ("format" "char_to_int")
                 ("cadr" "char_to_int")
                 ("caddr" "char_to_int")
                 ("cddr" "char_to_int")
                 ("cddadr" "char_to_int")
                 ("cdadr" "char_to_int")
                 ("caadr" "char_to_int")
                 ("caar" "char_to_int")
                 ("cdar" "char_to_int")
                 ("cdddr" "char_to_int")
                 ("cadddr" "char_to_int")
                 ("write-file" "char_to_int")
                 ("read-file" "char_to_int")
                 ;
                 ; End TODO
                 ;
                 ))

(define (initial-symbol-table)
  (cons (map car builtins) '()))

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
      (error (format "Symbol '~a' is not found" symbol))
      (let ([result (last-index-of (car table) symbol '() 0)])
        (if (null? result)
            (lookup symbol (cdr table) (+ level 1))
            (cons level result)))))
