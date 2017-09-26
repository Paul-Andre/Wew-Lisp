# Wew Lisp

This is a lisp interpreter I am writing for fun using nothing but assembly (x86_64 NASM).

At this point it is nowhere near functional, but can already interpret programs of the form:

```scheme
(define factorial (lambda (n) 
                    (if (<= n 1) 1
                      (* n (factorial (- n 1))))))

(list (factorial 1)
      (factorial 2)
      (factorial 3))

```
