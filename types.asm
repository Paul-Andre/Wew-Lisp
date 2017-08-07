
; Null array, also works as false
%define null_t 0

; 64-bit int. Also works as a pointer
%define int_t 1

; Points to a heap allocated cons cell
%define cons_t 2

; A symbol is a null-terminated string
%define symbol_t 3

; Built-in function
%define bi_fun_t 4

; A function defined in scheme
%define sc_fun_t 5

