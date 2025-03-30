; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

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
        (digits-to-number (cdr lst) (+ (* acc 10) (- digit (char->integer #\0)))))))

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

(list (match '(#\a #\b #\c)
        '(#\a #\c))
      (match '(#\a #\b #\c)
        '(#\a #\b)))
