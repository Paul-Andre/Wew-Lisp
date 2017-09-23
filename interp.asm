; Wew lads

%include "utils.asm"
%include "types.asm"
%include "parse.asm"
%include "print.asm"
%include "builtIns.asm"


SECTION .data


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

    ; Align the pointer to 32 bytes (size of a pair)
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
    call parseRestOfList
    push rax
    mov al, [rsi]
    cmp al, ')'
    errorE "unopened ')' at the end"

    mov byte [rsi], 0 ; A hack so that a single symbol can correctly be read
    pop rax


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


    call evalSequence



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


addDefineNodeToEnvironment:
    ; Basically this creates a new environment "frame" or something like that
    ; eh, maybe make this better defined and actually take the time to do this while I'm not tired, eh? Why don't you go to sleep, it's almost midnightttttttttt
    ; environment comes in to and out of rdi:rsi

    mov rax, [alloc_ptr]

    mov qword [rax], null_t
    mov qword [rax+8], 0
    mov [rax+16], rdi
    mov [rax+24], rsi

    mov rdi, pair_t
    mov rsi, [alloc_ptr]
    add qword [alloc_ptr], 32

    ret
    



addToEnvironmentWithDefine:
    ; When defining things with "define", to make sure that the definitions are mutually recursive,
    ; we pass an environment containing an indirection. 
    ; 
    ; For now, that indirection is a pair whose car is a null.
    ; addDefineNodeToEnvironment is used to get the redirection.
    ;
    ; The pointer to the environment list (a cons cell) is in rdi:rsi
    ; The symbol we insert with is in rdx:rcx
    ; The value we insert is in r8:r9
    ;
    cmp rdi, pair_t
    errorNe "Environment given to addToEnvironmentWithDefine isn't a pair"

    cmp qword [rsi], null_t
    errorNe "Are you trying to define inside an expression?"

    push rsi
    push rdi

    mov rdi, [rsi+16]
    mov rsi, [rsi+24]

    call addToEnvironment

    pop rax
    pop rax

    mov [rax+16], rdi
    mov [rax+24], rsi

    mov rdi, pair_t
    mov rsi, rax

    ret



addToEnvironment:
    ; The pointer to the environment list (a cons cell) is in rdi:rsi
    ; The symbol we insert with is in rdx:rcx
    ; The value we insert is in r8:r9
    ;
    ; The new environment is returned in rdi:rsi
    ;

        cmp rdx, symbol_t
        je .standardAdd

        cmp rdx, pair_t
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

        mov qword [r11], pair_t
        mov [r11 + 8], r10
        mov [r11 + 16], rdi
        mov [r11 + 24], rsi

        add qword [alloc_ptr], 32

        ;return it
        mov rdi, pair_t
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
        
        cmp r12, pair_t
        jne .notCons

        cmp r14, pair_t
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
        cmp rdi, pair_t
        jne exitError


        mov r8, [rsi]   ; car type
        mov r9, [rsi+8] ; car
        mov r10, [rsi+16] ;cdr type
        mov r11, [rsi+24] ;cdr

        ; Just a sanity check
        cmp r8, null_t
        je .tryNext

        cmp r8, pair_t
        errorNe "Something that's not a pair is in the environment list."


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
        
    .tryNext:
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
        je .selfQuoting
        cmp rdi, bool_t
        je .selfQuoting
        cmp rdi, char_t
        je .selfQuoting

        cmp rdi, pair_t
        je .pair
        cmp rdi, symbol_t
        je .symbol

        ; We shouldn't find anything else in the AST
        errorMsg "Trying to evaluate something that isn't valid AST"

    .selfQuoting:
        ret ;

    .pair:

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

        jmp .endPair


    .maybeQuote:
        mov rsi, r9
        mov rdi, quoteSymbol

        call cmpNullTerminatedStrings
        cmp rax, 0
        jne .maybeLambda


        mov r11, [r10 + 24] ; get the cdr
        mov r10, [r10 + 16]

        cmp r10, pair_t ; if cdr not a cons, is not correct
        jne exitError

        ; If it's a quote, we just return the car of the cdr as is
        mov rdi, [r11]
        mov rsi, [r11 + 8]

        jmp .endPair


    .maybeLambda:
        mov rsi, r9
        mov rdi, lambdaSymbol

        call cmpNullTerminatedStrings
        cmp rax, 0
        jne .maybeBegin

        mov r11, [r10 + 24] ; get the cdr
        mov r10, [r10 + 16]

        cmp r10, pair_t ; if cdr not a pair, is not correct
        jne exitError

        ; A lambda is a pair of its environment and its ast (excluding the "lambda" bit)

        mov rsi, [alloc_ptr]

        mov [rsi], rdx
        mov [rsi+8], rcx
        mov [rsi+16], r10
        mov [rsi+24], r11
        
        add qword [alloc_ptr], 32

        mov rdi, sc_fun_t

        jmp .endPair

    .maybeBegin:
        mov rsi, r9
        mov rdi, beginSymbol

        call cmpNullTerminatedStrings
        cmp rax, 0
        jne .maybeDefine

        mov rdi, [r10 + 16]
        mov rsi, [r10 + 24]

        jmp evalSequence ; tail call

    .maybeDefine:
        mov rsi, r9
        mov rdi, defineSymbol

        call cmpNullTerminatedStrings
        cmp rax, 0
        jne .notSpecialForm

        mov rdi, [r10 + 16]
        mov rsi, [r10 + 24]

        jmp handleDefine ; tail call

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

        jmp .endPair

    .maybeSchemeFunction: ; Maybe a lambda?
        cmp rdi, sc_fun_t 
        jne exitError

        mov r8, [r10 + 16] ; get the cdr
        mov r9, [r10 + 24]

        call handleSchemeApplication

        jmp .endPair
        
        
    .endPair:
        
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
        cmp rdi, pair_t
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


        cmp edi, bool_t
        jne .isTrue
        cmp rsi, 0
        je .isFalse
    .isTrue:

        ; we need to get and evaluate the caddr

        cmp r14, pair_t
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
        cmp r14, pair_t
        jne exitError

        mov rsi, r15
        mov r12, [rsi+16] ; cdddr type
        mov r13, [rsi+24] ; cdddr



        cmp r12, pair_t
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
        
        cmp r8, pair_t
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
    ; rdi:rsi is the function. we know it's a sc_fun_t
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
    cmp r10, pair_t
    jne exitError

    mov rdx, [r11]  ; the car of the cdr is tha argument list
    mov rcx, [r11 + 8]



    push r11

    call addToEnvironment

    call addDefineNodeToEnvironment

    pop r11
    

    ; Now the new environment is in rdi:rsi. Move it to rdx:rcx
    mov rdx, rdi
    mov rcx, rsi

    mov rdi, [r11 + 16]   ;the "cddr" of the lambda is the body.
    mov rsi, [r11 + 24]   ;the "cddr" of the lambda is the body.
    ; For now, we only consider a single expression, even though we should
    ; consider that there is an implicit "begin"

    ; There should be something in the lambda body
    ; (Though we probably want to check this at lambda creation time)
    cmp rdi, pair_t
    errorNe "Lambda must have body"

    jmp evalSequence; tail-call


handleDefine: 
    ;
    ; rdi:rsi
    ; rdx:rcx is the environment

    cmp edi, pair_t

    errorNe "'define' must be followed by two data."

    mov r8, [rsi]
    mov r9, [rsi+8]
    mov r10, [rsi+16]
    mov r11, [rsi+24]
    
    push r9
    push r8

    cmp r10d, pair_t
    errorNe "'define' must be followed by two data."

    mov r8, [r11]
    mov r9, [r11+8]
    mov r10, [r11+16]
    mov r11, [r11+24]

    cmp r10d, null_t
    errorNe "'define' must be followed by two data."

    mov rdi, r8
    mov rsi, r9

    push rcx
    push rdx

    call eval

    mov r8, rdi ; put the value in r8:r9
    mov r9, rsi

    pop rdi ; Put the environment in rdi:rsi
    pop rsi

    pop rdx ; Put the key in rdx:rcx
    pop rcx

    call addToEnvironmentWithDefine

    mov rdi, unspecified_t
    mov rsi, unspecified_value

    ret



evalSequence:
    ; Evaluates a sequences, which might contain defines
    ; Sequences are explicitly defined with `begin` or implicitly defined in the body of lambdas
    ;
    ; rdi:rsi is the list of instructions
    ; rdx:rcx is the environment
    ;



    ; What's a bit special about evalSequence is that it returns the result of the last operation.

    .loop:

        cmp edi, pair_t
        errorNe "What was passed to evalSequence isn't a list"

        mov r8, [rsi]
        mov r9, [rsi+8]
        mov r10, [rsi+16]
        mov r11, [rsi+24]

        cmp r10, null_t
        je .tailCall


        push r11
        push r10
        push rcx
        push rdx

        mov rdi, r8
        mov rsi, r9

        call eval

        pop rdx
        pop rcx
        pop rdi
        pop rsi 


        jmp .loop



    .tailCall:
        mov rdi, r8
        mov rsi, r9

        jmp eval

        
