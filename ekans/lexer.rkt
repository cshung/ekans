#lang racket

(require "../common/common.rkt")

(provide lexer
         read-file)

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

(define (digits-follows? suffix)
  (or (null? suffix) (member (car suffix) '(#\space))))

(define (lexer input)
  (if (null? input)
      (cons (cons 'eof '()) '())
      (let ([peek (car input)])
        (cond
          [(equal? peek lp) (cons (cons 'lparen '()) (cdr input))]
          [(equal? peek rp) (cons (cons 'rparen '()) (cdr input))]
          [(digit? peek)
           (let ([number-result (take-while input digit?)])
             (if (digits-follows? (cdr number-result))
                 (cons (cons 'number (digits-to-number (car number-result) 0)) (cdr number-result))
                 (cons (cons 'unknown '()) '())))]
          [else (cons (cons 'unknown '()) '())]))))

(define (read-file filename)
  (call-with-input-file filename
                        (lambda (port) (let ([content (port->string port)]) (string->list content)))))
