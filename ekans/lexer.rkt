; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require "../common/common.rkt")

(provide lexer)

(define (digit? c)
  (and (char>=? c #\0) (char<=? c #\9)))

(define (take-while input condition)
  (if (null? input)
      (cons '() '())
      (let ([head (car input)]
            [tail (cdr input)])
        (if (condition head)
            (let ([tail-result (take-while tail condition)])
              (cons (cons head (car tail-result)) (cdr tail-result)))
            (cons '() input)))))

(define (digits-to-number lst acc)
  (if (null? lst)
      acc
      (let ([digit (char->integer (car lst))])
        (digits-to-number (cdr lst) (+ (* acc 10) (- digit 48))))))

(define (token-end? suffix)
  (or (null? suffix) (member (car suffix) '(#\space #\newline #\( #\) #\[ #\]))))

(define (skip-comment input)
  (if (or (null? input) (equal? (car input) #\newline))
      input
      (skip-comment (cdr input))))

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
  (list (cons (string->list "#t") (cons 'bool #t)) (cons (string->list "#f") (cons 'bool #f))))

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
                 (if (pair? (cddr input))
                     (cons (cons 'character (caddr input)) (cdddr input))
                     (cons (cons 'unknown '()) '()))]
                ; Number
                [(digit? peek)
                 (let ([number-result (take-while input digit?)])
                   (if (token-end? (cdr number-result))
                       (cons (cons 'number (digits-to-number (car number-result) 0))
                             (cdr number-result))
                       (cons (cons 'unknown '()) '())))]
                ; String
                [(equal? peek #\")
                 (let ([string-result (take-while (cdr input) (lambda (c) (not (equal? c #\"))))])
                   (if (token-end? (cddr string-result))
                       (cons (cons 'string (list->string (car string-result))) (cddr string-result))
                       (cons (cons 'unknown '()) '())))]
                ; Symbol
                [else
                 (let* ([symbol-result (take-while input (lambda (c) (not (token-end? (list c)))))]
                        [symbol (car symbol-result)]
                        [symbol-value (list->string symbol)]
                        [tail (cdr symbol-result)])
                   (cons (cons 'symbol symbol-value) tail))]))))))
