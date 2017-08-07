
SECTION .bss

    numPrintBuffLen equ 80
	numPrintBuff: resb (numPrintBuffLen +1)

SECTION .text

print:
    ; type of input comes into rax
    ; input comes into rbx

        push rdi


    .maybeList:
        cmp rax, null_t
        je .isList

        cmp rax, cons_t
        je .isList

        jmp .maybeNumber

    .isList:
        push rax

        mov rdi, 1 ; print to stdout

        mov al, '('
        call printChar




        mov al, ' '
        call printChar

        pop rax

        call printRestOfList
        jmp .return


    .maybeNumber:
        cmp rax, int_t
        jne .maybeSymbol

        mov rax, rbx

        call printNumber

        jmp .return
        

    .maybeSymbol:
        cmp rax, symbol_t
        jne .error

        push rsi

        mov rsi, rbx
        call printNullTerminatedString

        pop rsi

        jmp .return

    .error:
        call exitError


    .return:
        pop rdi
        ret



printNullTerminatedString:
    ; string comes into rsi
        
        push rax
        push rdi
        push rdx

        push rsi

        mov rdx, 0

    .findLength:
        mov r9b, [rsi]
        cmp r9b, 0
        je .print

        inc rsi
        inc rdx
        jmp .findLength

    .print:

        mov rax, 1 ; write
        mov rdi, 1 ; stdout
        pop rsi ; get beginning of string
        ; rdx is the size of the string
        syscall

        pop rdx
        pop rdi
        pop rax
        ret




printRestOfList:
    ; type (null or cons) comes into rax
    ; value comes into rax

    push rdi


    .start:

    .maybeNull:
        cmp rax, null_t
        jne .notNull

        mov rdi, 1 ; print to stdout

        mov al, ')'
        call printChar

        jmp .return

    .notNull:
        cmp rax, cons_t
        jne .somethingElse

        push rax
        push rbx

        ; Get the car of the cons
        mov rax, [rbx]
        mov rbx, [rbx + 8]

        ; Print it
        call print

        mov rdi, 1 ; print char to stdout
        mov al, ' '
        call printChar

        pop rbx
        pop rax

        ; Get the cdr of the cons
        mov rax, [rbx + 16]
        mov rbx, [rbx + 24]

        ; recursive tail-call
        jmp .start



    .somethingElse: ; to consider the weird case of pairs whose cdr isn't a list (cons 1 1) = '(1 . 1)
        
        push rax


        mov rdi, 1 ; print to stdout

        mov al, '.'
        call printChar
        mov al, ' '
        call printChar


        pop rax

        call print

    
        mov rdi, 1 ; print to stdout
        mov al, ' '
        call printChar
        mov al, ')'
        call printChar

        jmp .return

    .return:
        pop rdi

        ret



printChar:
    ; character to print comes into al
    ; file to print to comes into rdi

    push rdi
    push rsi
    push rdx

    mov byte [rsp+8], al

    mov rax, 1
    ; rdi is already right
    lea rsi, [rsp+8]
    mov rdx, 1
    syscall

    pop rdx
    pop rsi
    pop rdi

    ret


printNumber:
	; number comes in rax
		
		push rax
		push rbx
		push rcx
		push rdx
        push rdi
        push rsi


        push rax

        mov rdi, numPrintBuff
        mov rcx, numPrintBuffLen
        mov rax, 0
        rep stosb

        pop rax
		
        mov rdi, numPrintBuff

	.checkIfSigned:
		cmp rax, 0
		jge .startBreakingUp
		mov byte [rdi], '-'
		inc rdi
		neg rax
		
		
	.startBreakingUp:
		
		
		mov rcx, 0 ;counter
		mov rbx, 10 ;variable to divide by 10
		
	.breakUpNumber:	
		mov rdx, 0
		div rbx  ;divide by 10
		push rdx
		inc rcx
		cmp rax, 0
		jne .breakUpNumber
	
	.writeNumber:
	
		cmp rcx, 0
		je .end
		
		pop rax
		add al, '0'
		stosb
		
		dec rcx
		jmp .writeNumber
	
	
	.end:
        ;mov al, `\n`
        ;stosb

        mov rdx, rdi
        sub rdx, numPrintBuff

        mov rax, 1
        mov rdi, 1 ; stdout
        mov rsi, numPrintBuff
        syscall



        pop rsi
        pop rdi
		pop rdx
		pop rcx
		pop rbx
		pop rax
	
ret


