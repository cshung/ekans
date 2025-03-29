(define (loop)
  (loop))

(and (or #t (loop)) #f (loop))
