#lang racket

(define lp #\()
(define rp #\))

(define (digit? c)
  (and (char>=? c #\0) (char<=? c #\9)))

(provide lp
         rp
         digit?)
