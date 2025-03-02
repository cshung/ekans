#lang racket

(provide parse-statement)
(provide parse-statements)

(require "../ekans/lexer.rkt")

;
; Grammar
;
; The current restricted language can only deal with a sequence of statement
; where each statement is just a number. This is meant to be expanded.
;
; prog = statements
; statements = epsilon | statement statements
; statement = number
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
      [else 'error])))
