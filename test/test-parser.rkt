#lang racket

(require rackunit "../ekans/parser.rkt")  
         
(provide test-parser)  
         
(define-test-suite test-parser
  (test-case "Test parser"
    (let ((test_sentence "I go to school by bus"))
    (check-equal? (parser test_sentence) test_sentence))))      