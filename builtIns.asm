
SECTION .data

    nullSymbol: db "null",0


SECTION .text

    
builtInAdd:

        mov rax, 0

        lea rdi, [rdi*2]
        lea rdi, [rdi*8]

    .loop:
        cmp rdi, 0
        je .return

        mov rsi, [rsp + rdi - 8]

        cmp rsi, int_t
        errorNe "Argument to '+' isn't an integer"

        add rax, [rsp + rdi]

        sub rdi, 8
        sub rdi, 8

        jmp .loop

    .return:

        mov rdi, int_t
        mov rsi, rax

        ret


builtInSub:

        cmp rdi, 0
        errorE "'-' must be called with at least one argument"

        cmp rdi, 1
        jne .actuallySub


    .negate:

        mov rdi, [rsp + 8]
        mov rsi, [rsp + 16]

        cmp rdi, int_t
        jne .typeError

        neg rsi

        ret


    .actuallySub:

        lea rdi, [rdi*2]
        lea rdi, [rdi*8]
        
        mov rdx, [rsp + rdi - 8]
        mov rcx, [rsp + rdi]

        sub rdi, 8
        sub rdi, 8

        cmp rdx, int_t
        jne .typeError

        mov rax, rcx

    .loop:
        cmp rdi, 0
        je .return

        mov rsi, [rsp + rdi - 8]

        cmp rsi, int_t
        jne .typeError

        sub rax, [rsp + rdi]

        sub rdi, 8
        sub rdi, 8

        jmp .loop

    .typeError:
        errorMsg "Argument to '-' isn't an integer"

    .return:

        mov rdi, int_t
        mov rsi, rax

        ret



builtInMul:

        mov rax, 1

        lea rdi, [rdi*2]
        lea rdi, [rdi*8]

    .loop:
        cmp rdi, 0
        je .return

        mov rsi, [rsp + rdi - 8]

        cmp rsi, int_t
        jne exitError

        mov rcx, [rsp + rdi]
        imul rcx

        sub rdi, 8
        sub rdi, 8

        jmp .loop

    .return:

        mov rdi, int_t
        mov rsi, rax

        ret

builtInIntEq:

        cmp rdi, 0
        je .argumentNumberError
        cmp rdi, 1
        je .argumentNumberError


    .takeFirst:

        lea rdi, [rdi*2]
        lea rdi, [rdi*8]
        
        mov rdx, [rsp + rdi - 8]
        mov rcx, [rsp + rdi]

        sub rdi, 8
        sub rdi, 8

        cmp rdx, int_t
        jne .typeError

        mov rax, rcx

    .loop:
        cmp rdi, 0
        je .returnEqual

        mov rsi, [rsp + rdi - 8]

        cmp rsi, int_t
        jne .typeError

        cmp rax, [rsp + rdi]
        jne .returnNotEqual

        sub rdi, 8
        sub rdi, 8

        jmp .loop

    .typeError:
        errorMsg "Argument to '=' isn't an integer"

    .argumentNumberError:
        errorMsg "'=' must be called with at least two argument"

    .returnEqual:

        mov rdi, bool_t
        mov rsi, 1

        ret

    .returnNotEqual:

        mov rdi, bool_t
        mov rsi, 0

        ret


%macro comparisonFunction 3

%1: 

        cmp rdi, 0
        je .argumentNumberError
        cmp rdi, 1
        je .argumentNumberError


    .takeFirst:

        lea rdi, [rdi*2]
        lea rdi, [rdi*8]
        
        mov rdx, [rsp + rdi - 8]
        mov rcx, [rsp + rdi]

        sub rdi, 8
        sub rdi, 8

        cmp rdx, int_t
        jne .typeError

        mov rax, rcx

    .loop:
        cmp rdi, 0
        je .returnEqual

        mov rsi, [rsp + rdi - 8]

        cmp rsi, int_t
        jne .typeError

        cmp rax, [rsp + rdi]
        %3 .returnNotEqual
        mov rax, [rsp + rdi]

        sub rdi, 8
        sub rdi, 8

        jmp .loop

    .typeError:
        errorMsg "Argument to comparison function isn't an integer"

    .argumentNumberError:
        errorMsg "Comparison functions must be called with at least two argument"

    .returnEqual:

        mov rdi, bool_t
        mov rsi, 1

        ret

    .returnNotEqual:

        mov rdi, bool_t
        mov rsi, 0

        ret

%endmacro


; Bloating the binary, generate a bunch of comparison functions
comparisonFunction builtInIntLt, "<", jge
comparisonFunction builtInIntGt, ">", jle
comparisonFunction builtInIntLeq, "<=", jg
comparisonFunction builtInIntGeq, ">=", jl



; This sub-procedure is to get 2 arguments passed to a built-in proc
; The zf will be preserved so a jne or je could be used after
get2Arguments:
        cmp rdi, 2
        je .correct
        ret
    
    .correct:
        ; Note that we need to jump over the return address
        mov rdi, [rsp + 32]
        mov rsi, [rsp + 40]
        mov rdx, [rsp + 16]
        mov rcx, [rsp + 24]

        ret
        
    


    
builtInCons:

        cmp rdi, 2
        errorNe "'cons' requires two arguments"

        mov r8, [rsp + 24]
        mov r9, [rsp + 32]
        mov r10, [rsp + 8]
        mov r11, [rsp + 16]

        mov rdi, [alloc_ptr]

        ; TODO: use vectorization

        mov [rdi], r8
        mov [rdi+8], r9
        mov [rdi+16], r10
        mov [rdi+24], r11
        
        add qword [alloc_ptr], 32

        mov rsi, rdi
        mov rdi, pair_t_full

        
        ret


builtInNot:

        cmp rdi, 1
        errorNe "'not' must have exactly one argument"

        mov rdi, [rsp + 8]
        mov rsi, [rsp + 16]

        cmp rdi, bool_t
        jne .returnFalse
        cmp rsi, 0
        jne .returnFalse

    .returnTrue:
        mov rdi, bool_t
        mov rsi, 1
        
        ret

    .returnFalse:

        mov rdi, bool_t
        mov rsi, 0
        
        ret


builtInList:


        mov r10, rdi

        mov rdi, null_t
        mov rsi, 0

        lea r10, [r10*2]
        lea r10, [r10*8]
        mov r11, 0

    .loop:

        
        cmp r10, r11
        je .return


        add r11, 8
        mov r8, [rsp + r11]
        add r11, 8
        mov r9, [rsp + r11]

        mov rax, [alloc_ptr]

        mov [rax], r8
        mov [rax + 8], r9
        mov [rax + 16], rdi
        mov [rax + 24], rsi

        mov rdi, pair_t_full
        mov rsi, [alloc_ptr]
        
        add qword [alloc_ptr], 32

        jmp .loop

    .return:

        ; At this point, rdi:rsi contains the answer
        
        ret

builtInGetType:
        

builtInVectorRef:

        call get2Arguments
        errorNe "'vector-ref' requires 2 arguments"

        ;call printWrapper

        mov r8, vector_mask
        and r8, rdi

        mov r9, vector_mask
        cmp qword r8, r9
        errorNe "Something that isn't essentially a vector was passed to 'vector-ref'"

        cmp rdx, int_t
        errorNe "Second argument of 'vector-ref' isn't an integer"

        mov r8, rdi
        shr r8, 32
        and r8, size_mask

        cmp rcx, 0
        jl .notInRange

        cmp r8, rcx
        jle .notInRange

        lea rcx, [rcx*2]

        mov rdi, [rsi + rcx*8]
        mov rsi, [rsi + rcx*8 + 8]


        ret

    .notInRange:
        errorMsg "Integer passed to vector-ref is not in range"
        
        




%macro insertFunctionIntoEnvironment 2
    ; embed the string in the source... what???
    jmp %%after
    %%string: db %2, 0
    %%after:

    mov rdx, symbol_t
    mov rcx, %%string
    mov r8, bi_fun_t
    mov r9, %1

    call addToEnvironment

%endmacro



createInitialEnvironment:

    ; Places all the built-in functions into the environment

    mov rdi, null_t
    mov rsi, 0

    mov rdx, symbol_t
    mov rcx, nullSymbol
    mov r8, null_t
    mov r9, 0

    call addToEnvironment

    insertFunctionIntoEnvironment builtInAdd, "+"
    insertFunctionIntoEnvironment builtInSub, "-"
    insertFunctionIntoEnvironment builtInMul, "*"
    insertFunctionIntoEnvironment builtInIntEq, "="
    insertFunctionIntoEnvironment builtInIntLt, "<"
    insertFunctionIntoEnvironment builtInIntGt, ">"
    insertFunctionIntoEnvironment builtInIntLeq, "<="
    insertFunctionIntoEnvironment builtInIntGeq, ">="
    insertFunctionIntoEnvironment builtInNot, "not"
    insertFunctionIntoEnvironment builtInVectorRef, "vector-ref"
    insertFunctionIntoEnvironment builtInCons, "cons"
    insertFunctionIntoEnvironment builtInList, "list"


    call addDefineNodeToEnvironment

    ret

