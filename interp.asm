; Wew lads

%include "types.asm"
%include "parse.asm"
%include "print.asm"


SECTION .data
    genericErrorMsg: db `There was some error.\n`
	genericErrorMsgLen equ $-genericErrorMsg

    testSymbol: db "abc"
    db 0


SECTION .bss
    heap_start: resq 1
    program_end: resq 1

    alloc_ptr: resq 1


SECTION .text

    global _start


_start:




; Allocate memory for the heap:

        ; Get the current brk address
        mov rax, 12 ; brk
        mov rdi, 0 
        syscall

        ; Save the info
        mov [alloc_ptr], rax
        mov [heap_start], rax

        ; Allocate some arbitrary number of bytes
        mov rdi, rax
        add rdi, 1000000

        ; Syscall
        mov rax, 12
        syscall



; Read the source code into the heap

    reading_loop:

        ; Read from stdin
        mov rax, 0
        mov rdi, 0 ; stdin
        mov rsi, [alloc_ptr]
        mov rdx, 100000
        syscall

        add [alloc_ptr], rax

        cmp rax, 0
        jne reading_loop

    ; After the loop:

        ; Save the end of the program
        mov rax, [alloc_ptr]
        mov [program_end], rax

        ; Add a null terminator
        mov byte [rax], 0
        inc rax

    ; Align the pointer to 32 bytes (size of a cons)
    align_loop:
        mov rdi, rax
        and rdi, 0x1f
        cmp rdi, 0
        je align_loop_break

        inc rax
        jmp align_loop
        
    align_loop_break:
        mov [alloc_ptr], rax




; parse the code
    mov rsi, [heap_start]
    call parse
    mov byte [rsi], 0 ; A hack so that a single symbol can correctly be read


; play around with environment

    push rax ; PARSING ISN'T CLOSE TO SYSTEM-V AT ALL
    push rbx


    mov rdi, null_t
    mov rsi, 0

    mov rdx, symbol_t
    mov rcx, testSymbol

    mov r8, int_t
    mov r9, 42

    call addToEnvironment



    pop rbx
    pop rax

    mov rdx, rdi
    mov rcx, rsi
    mov rdi, rax
    mov rsi, rbx


    call eval



    mov rax, rdi
    mov rbx, rsi

    call print ; PRINTING ISN'T SYSTEM-V BUT SHOULD BE SINCE IT WORKS WITH SYSCALLS


; Exit

        mov rax, 60
        mov rdi, 0
        syscall



cmpNullTerminatedStrings:
    ; String pointers come into rdi and rsi
    ; returns 0 in rax if strings are equal, something else if they are not
    ; (idea is that eventually we might also say whether one of them is bigger than the other)

    .loop:
        mov r8b, [rdi]
        mov r9b, [rsi]
        cmp r8b, r9b
        je .same
        jmp .negative

    .same:
        cmp r8b, 0
        je .positive

        inc rdi
        inc rsi
        jmp .loop

    .positive:
        mov rax, 0
        jmp .return

    .negative:
        mov rax, 1
        jmp .return

    .return:
        ret


addToEnvironment:
    ; The pointer to the environment list (a cons cell) is in rdi:rsi
    ; The symbol we insert with is in rdx:rcx
    ; The value we insert is in r8:r9
    ;
    ; The new environment is returned in rdi:rsi
    ;

    ; Eventually I'd like to be able to work with a list of symbols for some
    ; kind of pattern matching, but for now it must be a symbol

    cmp rdx, symbol_t
    jne exitError

    ; create the (symbol, value) pair
    mov r10, [alloc_ptr]

    mov [r10], rdx
    mov [r10 + 8], rcx
    mov [r10 + 16], r8
    mov [r10 + 24], r9

    add qword [alloc_ptr], 32

    ; create the ((symbol, value), previousEnvironment) pair
    mov r11, [alloc_ptr]

    mov qword [r11], cons_t
    mov [r11 + 8], r10
    mov [r11 + 16], rdi
    mov [r11 + 24], rsi

    add qword [alloc_ptr], 32

    ;return it
    mov rdi, cons_t
    mov rsi, r11

    ret




findInEnvironment:
    ; An environment is a list of pairs
    ; Bindings closer to the beginning shadow those closer to the end

    ; The pointer to the environment list (a cons cell) is in rdi:rsi
    ; A pointer to the string we are searching for comes into rdx

    ; The found value comes out of rdi:rsi
    ;

        push r12
        push r13
        push r14
        push r15

        
        ; Check if the input is a cons.
        ; It might be a null if the variable isn't in the environment
        ; TODO make a clearer error message about this
        cmp rdi, cons_t
        jne exitError


        mov r8, [rsi]   ; car type
        mov r9, [rsi+8] ; car
        mov r10, [rsi+16] ;cdr type
        mov r11, [rsi+24] ;cdr

        ; Just a sanity check
        cmp r8, cons_t
        jne exitError


        mov r12, [r9] ; (car (car x)) type
        mov r13, [r9+8] ; (car (car x))
        mov r14, [r9+16] ; (cdr (car x)) type
        mov r15, [r9+24] ; (cdr (car x))


        ; Again sanity check
        cmp r12, symbol_t
        jne exitError



        mov rdi, r13
        mov rsi, rdx

        push r10
        push r11


        call cmpNullTerminatedStrings

        pop r11
        pop r10

        cmp rax, 0
        je .success 
        mov rdi, r10
        mov rsi, r11

        call findInEnvironment

        jmp .return


    .success:

        mov rdi, r14
        mov rsi, r15
        jmp .return

    .return:

        pop r15
        pop r14
        pop r13
        pop r12


        ret







eval:
    ; The expression to be evaled goes into rdi:rsi
    ; The environment (pointer to a cons or null) goes into rdx:rcx
    ;
    ; The evaluated result comes out of rdi:rsi
    ; The modified environment comes out of rdx:rcx

        cmp rdi, null_t
        je exitError
        cmp rdi, int_t
        je .int
        cmp rdi, cons_t
        je .cons
        cmp rdi, symbol_t
        je .symbol

        jmp exitError ; We shouldn't find anything else in the AST

    .int:
        ret ; Integers are "self-quoting"

    .cons:
        jmp exitError ; NOT IMPLEMENTED

    .symbol:
        push rdx
        push rcx

        mov rdi, rdx
        mov rdx, rsi
        mov rsi, rcx


        call findInEnvironment


        pop rcx
        pop rdx

        ret



exitError:

    ; First print a generic error message:
        mov rax, 1
        mov rdi, 2 ; stderr
        mov rsi, genericErrorMsg
        mov rdx, genericErrorMsgLen
        syscall


    ; rdi specifies return code
        mov rax, 60
        mov rdi, 1
        syscall
    
    
