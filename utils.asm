
SECTION .data
    genericErrorMsg: db `\nERROR!\n`
	genericErrorMsgLen equ $-genericErrorMsg





%macro errorMsg 1 
    
    jmp %%over
    %%msg: db %1
    %%len equ $-%%msg

    %%over:

    mov rsi, %%msg
    mov rdx, %%len

    call printAndExit

%endmacro


%macro errorNe 1

    je %%over

    errorMsg %1

    %%over:
%endmacro


%macro errorE 1
    jne %%over

    errorMsg %1

    %%over:
%endmacro




printAndExit:
    ; This is to be used in the macros

    ; rsi should be message
    ; rdx should be length

        mov rax, 1
        mov rdi, 2 ; stderr
        syscall

        jmp exitError


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
    
