; Wew lads

%include "types.asm"
%include "parse.asm"
%include "print.asm"
%include "builtIns.asm"


SECTION .data
    genericErrorMsg: db `There was some error.\n`
	genericErrorMsgLen equ $-genericErrorMsg



    ; Special forms:

    ifSymbol: db "if",0
    quoteSymbol: db "quote",0
    lambdaSymbol: db "lambda",0

    beginSymbol: db "begin",0
    defineSymbol: db "define",0
    letSymbol: db "let",0
    setSymbol: db "set!",0




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


    call createInitialEnvironment


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
        mov al, [rsi]
        cmp r8b, al
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
        je .standardAdd

        cmp rdx, cons_t
        je .listAdd
        cmp rdx, null_t
        je .listAdd
        jmp  exitError


    .listAdd:
        call addListToEnv

        jmp .return

    .standardAdd:

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

        jmp .return

    .return:

        ret



addListToEnv:
    ; The pointer to the environment list (a cons cell) is in rdi:rsi
    ; The symbols we insert with are in rdx:rcx (should be a list)
    ; The values we insert are in r8:r9 (should be a list)
    ;
        

        push r12
        push r13
        push r14
        push r15

        mov r12, rdx
        mov r13, rcx
        mov r14, r8
        mov r15, r9

    .loop:
        
        cmp r12, cons_t
        jne .notCons

        cmp r14, cons_t
        jne exitError

        mov rdx, [r13] ;car of symbols
        mov rcx, [r13+8]
        mov r12, [r13+16] ; cdr of symbols
        mov r13, [r13+24]

        mov r8, [r15] ;car of values
        mov r9, [r15+8]
        mov r14, [r15+16] ; cdr of values
        mov r15, [r15+24]

        ; At this point, rdx:rcx contains a symbol and r8:r9 contains a value
        ; rdi:rsi contains previous environment

        call addToEnvironment

        ; At this point, rdi:rsi contains new environment

        jmp .loop
        

    .notCons:
        cmp r12, null_t
        je .isNull

        jmp exitError; (We don't handle weird . thing yet)

    .isNull:
        ; Verify that the length of the values is the same
        cmp r14, null_t
        jne exitError

        jmp .return

    .return:

        pop r15
        pop r14
        pop r13
        pop r12

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

        mov r8, [rsi] ; (car exp) type
        mov r9, [rsi+8] ; (car exp)
        mov r10, rsi

        cmp r8, symbol_t
        jne .notSpecialForm

    ; Check if "if"

    .maybeIf:
        mov rsi, r9
        mov rdi, ifSymbol

        call cmpNullTerminatedStrings

        cmp rax, 0
        jne .maybeQuote

        mov rdi, [r10 + 16]
        mov rsi, [r10 + 24]

        call handleIf;

        jmp .endCons


    .maybeQuote:
        mov rsi, r9
        mov rdi, quoteSymbol

        call cmpNullTerminatedStrings
        cmp rax, 0
        jne .maybeLambda


        mov r11, [r10 + 24] ; get the cdr
        mov r10, [r10 + 16]

        cmp r10, cons_t ; if cdr not a cons, is not correct
        jne exitError

        ; If it's a quote, we just return the car of the cdr as is
        mov rdi, [r11]
        mov rsi, [r11 + 8]

        jmp .endCons


    .maybeLambda:
        mov rsi, r9
        mov rdi, lambdaSymbol

        call cmpNullTerminatedStrings
        cmp rax, 0
        jne .notSpecialForm

        mov r11, [r10 + 24] ; get the cdr
        mov r10, [r10 + 16]

        cmp r10, cons_t ; if cdr not a cons, is not correct
        jne exitError

        ; A lambda is a pair of its environment and its ast (excluding the "lambda" bit)

        mov rsi, [alloc_ptr]

        mov [rsi], rdx
        mov [rsi+8], rcx
        mov [rsi+16], r10
        mov [rsi+24], r11
        
        add qword [alloc_ptr], 32

        mov rdi, sc_fun_t

        jmp .endCons


    .notSpecialForm:

        mov rdi, [r10] ; Get the car
        mov rsi, [r10 + 8]

        push rdx
        push rcx
        push r10

        call eval

        pop r10
        pop rcx
        pop rdx
        
        cmp rdi, bi_fun_t ; built-in function
        jne .maybeSchemeFunction

        mov r8, [r10 + 16] ; get the cdr
        mov r9, [r10 + 24]

        call handleBuiltInApplication

        jmp .endCons

    .maybeSchemeFunction: ; Maybe a lambda?
        cmp rdi, sc_fun_t 
        jne exitError

        mov r8, [r10 + 16] ; get the cdr
        mov r9, [r10 + 24]

        call handleSchemeApplication

        jmp .endCons
        
        
    .endCons:
        
        jmp .return

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
        jmp .return


    .return: 

        ret


handleIf:
    ; rdi:rsi is (cdr exp)
    ; rdx:rcx is environment
    ;
    ; returns in rdi:rsi
    ; returns environment in rdx:rcx

        push r12
        push r13
        push r14
        push r15

        ; If cdr isn't a list, it's worthless
        cmp rdi, cons_t
        jne exitError

        mov r12, [rsi] ; (car (cdr exp)) type (the condition)
        mov r13, [rsi+8] ; (car (cdr exp)) 
        mov r14, [rsi+16] ; (cdr (cdr exp)) type
        mov r15, [rsi+24] ; (cdr (cdr exp))

        mov rdi, r12
        mov rsi, r13

        push rdx
        push rcx

        call eval

        pop rcx
        pop rdx


        ; In my dialect, for simplicity null is the same as false
        cmp rdi, null_t
        je .isFalse
    .isTrue:

        ; we need to get and evaluate the caddr

        cmp r14, cons_t
        jne exitError

        mov rsi, r15
        mov r12, [rsi] ; caddr type
        mov r13, [rsi+8] ; caddr

        mov rdi, r12
        mov rsi, r13

        push rdx
        push rcx

        call eval

        pop rcx
        pop rdx


        jmp .return
    .isFalse:

        ; we need to get and evaluate the cadddr
        cmp r14, cons_t
        jne exitError

        mov rsi, r15
        mov r12, [rsi+16] ; cdddr type
        mov r13, [rsi+24] ; cdddr



        cmp r12, cons_t
        jne exitError

        mov rsi, r13
        mov r12, [rsi] ; cadddr type
        mov r13, [rsi+8] ; cadddr

        mov rdi, r12
        mov rsi, r13

        push rdx
        push rcx

        call eval

        pop rcx
        pop rdx

        jmp .return

    .return:

        pop r15
        pop r14
        pop r13
        pop r12

        ret






%macro pushEverything 0
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

%endmacro
    
%macro popEverything 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

%endmacro


printWrapper:
    pushEverything

    mov rax, rdi
    mov rbx, rsi

    call print

    popEverything

    ret


handleBuiltInApplication:
    ; rdi:rsi is the function. rdi doesn't really matter tho since we know it's bi_fun_t
    ; rdx:rcx is the environment of course
    ; r8:r9 is the argument list
    ;
    ; rdi:rsi value out
    ; Let's assume that there is no environment out
    ;
    ; As I evaluate the arguments, I put them onto the stack.
    ; Then I put the number of arguments into rdi and call the function
    ; Value should be returned to rdi:rsi
    ; Functions should follow system-v clobbered/preserved convention

    push r12
    push r13
    push r14
    push r15

    mov rax, 0
    
    .argEvalLoop:
        cmp r8, null_t
        je .break
        
        cmp r8, cons_t
        jne exitError

        mov r12, [r9]
        mov r13, [r9+8]
        mov r14, [r9+16]
        mov r15, [r9+24]

        push rax
        push rdx
        push rcx
        push rsi

        mov rdi, r12
        mov rsi, r13

        call eval


        mov r10, rdi
        mov r11, rsi

        pop rsi
        pop rcx
        pop rdx
        pop rax


        push r11 ; These pushes are special. They are used to pass the arguments
        push r10

        mov r8, r14
        mov r9, r15

        inc rax
        jmp .argEvalLoop

    .break:

        ; Now it's the time to evaluate that function
        mov r12, rax ; We need to save the number of arguments somewhere not on the stack
        mov rdi, rax

        call rsi
        
        ; Now the answer should be in rdi:rsi
        ; Time to clean the stack

        lea r12, [r12*2]
        lea rsp, [rsp + r12*8] ; subtract rsi*16 from the stack
        ; This is equivalent to popping r12*2 times
        
    .return:
    
        pop r15
        pop r14
        pop r13
        pop r12

        ret



handleSchemeApplication:
    ; rdi:rsi is the function. we know it's a bi_fun_t
    ; rdx:rcx is the environment of course
    ; r8:r9 is the argument list
    ; 
    ; rdi:rsi value out
    ; Let's assume that there is no environment out
    ;
    ; What I'm going to do is that I'm going to evaluate builtInList on the
    ; argument list and then put it into the environment and eval the AST

    push rsi

    push rdx
    push rcx

    mov rdi, bi_fun_t
    mov rsi, builtInList

    call handleBuiltInApplication

    pop rcx
    pop rdx

    ; Now rdi:rsi contains the list we want to insert into env
    mov r8, rdi
    mov r9, rsi
    
    pop rsi

    mov rax, rsi


    mov rdi, [rax]    ; the "car" of the lambda is the environment
    mov rsi, [rax + 8]

    mov r10, [rax + 16]  ; the "cdr" of the lambda is the argument list and the body AST
    mov r11, [rax + 24]

    ; Better check this at creation time...
    cmp r10, cons_t
    jne exitError

    mov rdx, [r11]  ; the car of the cdr is tha argument list
    mov rcx, [r11 + 8]




    push r11

    call addToEnvironment

    pop r11

    ; Now the new environment is in rdi:rsi. Move it to rdx:rcx
    mov rdx, rdi
    mov rcx, rsi

    mov rdi, [r11 + 16]   ;the "cdr" "cdr" of the lambda is the body.
    mov rsi, [r11 + 24]   ;the "cdr" "cdr" of the lambda is the body.
    ; For now, we only consider a single expression, even though we should
    ; consider that there is an implicit "begin"

    ; There should be something in the lambda body
    ; (Though we probably want to check this at lambda creation time)
    cmp rdi, cons_t
    jne exitError


    mov rdi, [rsi]     ; The first expression of the body
    mov rsi, [rsi + 8]


    jmp eval; tail-call








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
    
    
