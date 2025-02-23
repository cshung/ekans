#lang racket

(require rackunit/text-ui 
         "test-lexer.rkt" 
         "test-parser.rkt")

(run-tests test-lexer)
(run-tests test-parser)