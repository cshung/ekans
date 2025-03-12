; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(define lp #\()
(define rp #\))
(define empty-string "")

(define (list-start? token)
  (and (not (null? token))
       (equal? (car token) #\')
       (not (null? (cdr token)))
       (equal? (car (cdr token)) lp)))

(provide lp
         rp
         empty-string
         list-start?)
