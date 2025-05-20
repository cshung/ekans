; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require rackunit
         rackunit/text-ui
         "../ekans/lexer.rkt"
         "../common/common.rkt")

(define-test-suite
 test-lexer
 (test-case "Test multiple line comments"
   (check-equal? (lexer (string->list ;
                         "; 床前明月光，\n;疑是地上霜。\n;舉頭望明月，\n;下一句係乜嘢\n1234567"))
                 (cons (cons 'number 1234567) '())))
 (test-case "Test single line comments"
   (check-equal? (lexer (string->list ;
                         "; London Bridge Is Falling Down\n;1234567\n#f"))
                 (cons (cons 'bool #f) '())))
 (test-case "Test EOF"
   (check-equal? (lexer (string->list "")) (cons (cons 'eof '()) '())))
 (test-case "Test lparen"
   (check-equal? (lexer (string->list "()")) (cons (cons 'lparen '()) (list rp))))
 (test-case "Test rparen"
   (check-equal? (lexer (string->list ")(")) (cons (cons 'rparen '()) (list lp))))
 (test-case "Test single digit"
   (check-equal? (lexer (string->list "3")) (cons (cons 'number 3) '())))
 (test-case "Test multiple digits"
   (check-equal? (lexer (string->list "357")) (cons (cons 'number 357) '())))
 (test-case "Test digit following a valid suffix case"
   (check-equal? (lexer (string->list "357 ")) (cons (cons 'number 357) '(#\space))))
 (test-case "Test digit following an invalid suffix case"
   (check-equal? (lexer (string->list "357a z")) (cons (cons 'unknown '()) '())))
 (test-case "Test false following a valid suffix case"
   (check-equal? (lexer (string->list "#f ")) (cons (cons 'bool #f) '(#\space))))
 (test-case "Test false following a invalid suffix case"
   (check-equal? (lexer (string->list "#fa ")) (cons (cons 'symbol "#fa") '(#\space))))
 (test-case "Test quoted list"
   (check-equal? (lexer (string->list "'(1 2 3)")) (cons (cons 'quote '()) (string->list "(1 2 3)"))))
 (test-case "Test ++("
   (check-equal? (lexer (string->list "++(")) (cons (cons 'symbol "++") (list lp))))
 (test-case "Test Operator Addition"
   (check-equal? (lexer (string->list "+ 1 2")) (cons (cons 'symbol "+") (string->list " 1 2"))))
 (test-case "Test Operator Subtraction"
   (check-equal? (lexer (string->list "- 1 2")) (cons (cons 'symbol "-") (string->list " 1 2"))))
 (test-case "Test Operator Multiplication"
   (check-equal? (lexer (string->list "* 1 2")) (cons (cons 'symbol "*") (string->list " 1 2"))))
 (test-case "Test Operator Division"
   (check-equal? (lexer (string->list "/ 1 2")) (cons (cons 'symbol "/") (string->list " 1 2"))))
 (test-case "Test character"
   ; Input: "#\\a"
   ; Breakdown:
   ;   1. #\# -> #
   ;   2. #\\ -> \
   ;   3. #\a -> a
   ; Expected Output: (# \ a)
   ; (displayln (string-append "[log][test-lexer] " (format "~a" (string->list "#\\a"))))
   (check-equal? (lexer (string->list "#\\a")) (cons (cons 'character #\a) '())))
 (test-case "Test #\\newline only"
   (check-equal? (lexer (string->list "#\\newline")) (cons (cons 'character #\newline) '())))
 (test-case "Test #\\newline with other characters"
   (check-equal? (lexer (string->list "#\\newline 123"))
                 (cons (cons 'character #\newline) (string->list " 123"))))
 ; add more test cases here
 )

(run-tests test-lexer)
