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

(digits-to-number '(#\1 #\2 #\3) 0)