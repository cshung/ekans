; Use this file to incrementally bring the ekans compiler to ekans

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

; A non-empty body is required to make sure the generated program has something to do
; We can use this area to do some adhoc testing of the ported functions
1