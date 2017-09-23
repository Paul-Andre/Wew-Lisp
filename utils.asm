
SECTION .data
    genericErrorMsg: db `\nERROR!\n`
	genericErrorMsgLen equ $-genericErrorMsg
    genericExitErrorMsg: db `\nTHERE WAS SOME ERROR!\n`
	genericExitErrorMsgLen equ $-genericExitErrorMsg





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


exitError:

    ; First print a generic error message:
        mov rax, 1
        mov rdi, 2 ; stderr
        mov rsi, genericExitErrorMsg
        mov rdx, genericExitErrorMsgLen
        syscall


    ; rdi specifies return code
        mov rax, 60
        mov rdi, 1
        syscall
    



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
