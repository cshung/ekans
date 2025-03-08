; Copyright (c) 2025 Good Night, Good Morning and contributors (see Contributors.md)
; Licensed under the MIT License. See the LICENSE file in the project root for details.

#lang racket

(define lp #\()
(define rp #\))
(define empty-string "")
(define prologue "#include <stdio.h>\n\nint main(void) {\n")
(define epilogue "  return 0;\n}\n")

(provide lp
         rp
         empty-string
         prologue
         epilogue)
