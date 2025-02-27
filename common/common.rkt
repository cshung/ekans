#lang racket

(define lp #\()
(define rp #\))

(define (digit? c)
  (and (char>=? c #\0) (char<=? c #\9)))

(define (all-digits? input)
  (andmap digit? input))

(define (takeWhile input condition)
  (if (null? input)
      (cons '() '())
      (let ([head (car input)]
            [tail (cdr input)])
        (if (condition head)
            (let ([tail-result (takeWhile tail condition)])
              (cons (cons head (car tail-result)) (cdr tail-result)))
            (cons '() input)))))

(provide lp
         rp
         digit?
         all-digits?
         takeWhile)
