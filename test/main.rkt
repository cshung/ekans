; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(require rackunit/text-ui
         "test-lexer.rkt"
         "test-parser.rkt")

(run-tests test-lexer)
(run-tests test-parser)
