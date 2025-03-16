; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(provide new-variable-id)
(provide number-of-variables)
(provide increment-variable-id)
(provide new-function-id)
(provide number-of-functions)
(provide increment-function-id)
(provide symbol-table)
(provide enqueue-pending-function)
(provide pending-functions)

(define (new-variable-id context)
  (+ (car context) 1))

(define (number-of-variables context)
  (car context))

(define (increment-variable-id context)
  (cons (+ (car context) 1) (cdr context)))

(define (new-function-id context)
  (+ (cadr context) 1))

(define (number-of-functions context)
  (cadr context))

(define (increment-function-id context)
  (cons (car context) (cons (+ (cadr context) 1) (cddr context))))

(define (symbol-table context)
  (caddr context))

(define (enqueue-pending-function id body context)
  (list (car context) ; variable unchanged
        (cadr context) ; num function unchanged
        (caddr context) ; symbol table unchanged
        (cons (list id body context) (cadddr context))))

(define (pending-functions context)
  (cadddr context))
