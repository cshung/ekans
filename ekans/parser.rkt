; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(provide parse-statement)
(provide parse-statements)

(require "lexer.rkt")

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
