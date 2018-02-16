# Wew Lisp

This is a lisp interpreter I am writing for fun using nothing but assembly (x86_64 NASM) and linux syscalls.

Even though it lacks many features, it can already execute simple programs, for example:

```scheme
(define factorial (lambda (n) 
                    (if (<= n 1) 1
                      (* n (factorial (- n 1))))))

(list (factorial 1)
      (factorial 2)
      (factorial 3))

```

## Instructions:

To assemble and link:
```bash
nasm -felf64 interp.asm
ld interp.o -o interp
```
To run a program, pipe it into the interpreter's standard input. At this time, there is no repl mode, so the program is parsed and run only once the standard input reaches its end.

```bash
./interp < factorial.scm
```

## Design principles

While this is not meant to be a Scheme (Scheme has quite a few tricky features), I plan on using a similar API as Scheme when possible.
