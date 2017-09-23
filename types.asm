; Each Scheme object will be represented by a 128 bit value. The first word
; contains type information and the second word contains data or a pointer to
; data.

; The higher 32 bits represent information used by the memory manager.

; The highest 4 bits are used to identify what "kind" of heap allocated data it is and the rest represents its size.

; On linux, user-space addresses must have a 0 in their higher bit.
; By setting the highest bit of GC'ed types to 1, we make sure that no pointer
; saved on the stack is ever going to be confused for an object type.

; The highest bit is always 1 for the type of heap allocated objects.

; The lower 32 bits is a number that should identify the actual object type


%define vector_mask ((0b1001) << (64 - 4))
%define buffer_mask ((0b1010) << (64 - 4))

%define size_mask 0x0fffffff

; Null array
%define null_t 0

; What to return from things that shouldn't return anything
%define unspecified_t 0
%define unspecified_value 0

; Boolean
%define bool_t 1

; 64-bit integer
%define int_t 2

; Unicode character
%define char_t 4

; Points to a heap allocated cons cell
%define pair_t 5
%define pair_t_full (5 | (2 << 32) | vector_mask)

; A symbol is a null-terminated string
%define symbol_t 6

; Built-in function
%define bi_fun_t 7

; A function defined in scheme
%define sc_fun_t 8
%define sc_fun_t_full 8 | (2 << 32) | vector_mask

