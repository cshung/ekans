; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(provide initial-symbol-table)
(provide lookup)
(provide last-index-of)
(provide builtins)

(define builtins
  '(("+" "plus") ("-" "subtract")
                 ("*" "multiply")
                 ("/" "division")
                 ("not" "not")
                 ("char<=?" "char_le")
                 ("char>=?" "char_ge")
                 ("cons" "list_cons")
                 ("list" "list_constructor")
                 ("=" "equals")
                 ("eq?" "equals")
                 ("equal?" "equals")
                 ("null?" "is_null")
                 ("member" "member")
                 ("car" "car")
                 ("cdr" "cdr")
                 ("char->integer" "char_to_int")
                 ("string->list" "string_to_list")
                 ("get-args" "args")
                 ("displayln" "println")
                 ("<" "less")
                 (">" "greater")
                 ("error" "failfast")
                 ("pair?" "is_pair")
                 ;
                 ; Begin TODO
                 ;
                 ("list->string" "char_to_int")
                 ("string-append" "char_to_int")
                 ("format" "char_to_int")
                 ("cadr" "char_to_int")
                 ("caddr" "char_to_int")
                 ("cddr" "char_to_int")
                 ("cddadr" "char_to_int")
                 ("cdadr" "char_to_int")
                 ("caadr" "char_to_int")
                 ("caar" "char_to_int")
                 ("cdar" "char_to_int")
                 ("cdddr" "char_to_int")
                 ("cadddr" "char_to_int")
                 ("write-file" "char_to_int")
                 ("read-file" "char_to_int")
                 ;
                 ; End TODO
                 ;
                 ))

(define (initial-symbol-table)
  (cons (map car builtins) '()))

(define (last-index-of l target current index)
  (if (null? l)
      current
      (let ([head (car l)]
            [rest (cdr l)])
        (if (equal? head target)
            (last-index-of rest target (list index) (+ index 1))
            (last-index-of rest target current (+ index 1))))))

(define (lookup symbol table level)
  (if (null? table)
      (error (format "Symbol '~a' is not found" symbol))
      (let ([result (last-index-of (car table) symbol '() 0)])
        (if (null? result)
            (lookup symbol (cdr table) (+ level 1))
            (cons level result)))))
