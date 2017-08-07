
SECTION .text

parse:
    ; string pointer comes into rsi

    ; type of output comes out of rax
    ; value of output comes out of rbx
    ; string pointer to rest of the string stays in rsi

    ; I do this hack where I replace whitespace and parentheses with '\0' so that symbols can be just pointers into source code

        call skipSpaces

        mov al, [rsi]

    .checkIfList:

        cmp al, '('
        jne .checkIfNum

        mov byte [rsi], 0
        inc rsi


        call parseRestOfList

        ret

    .checkIfNum:
        
        cmp al, '0'
        jb .mustBeSymbol

        cmp al, '9'
        ja .mustBeSymbol

        call parseNum

        mov rbx, rax
        mov rax, int_t

        ret

    .mustBeSymbol:

        cmp al, ')'
        je .error
        
        mov rax, symbol_t
        mov rbx, rsi

        call findEndOfSymbol

        ret

    .error:
        call exitError



    


findEndOfSymbol:
    ; string pointer comes into rsi

    ; string pointer of string after symbol comes out of rsi

		
	.start:
		mov r8b, [rsi]
	
		cmp r8b, ' '
		je .end
        cmp r8b, ')'
		je .end
        cmp r8b, '('
		je .end
		cmp r8b, `\t`
		je .end
		cmp r8b, `\n` ; something something line break carriage return XXX
		je .end

		inc rsi
		jmp .start
		
	.end:

    ret



        
    

        


parseNum:
    ; string pointer comes into rsi

    ; number comes out of rax
    ; pointer to rest of string will stay in rsi
		
		push rbx
		push rcx
		push rdx
		push rdi
		

        mov rcx, 0
		
	.getDigits:

		mov rax, 0
		mov al, [rsi]

        cmp al, '0'
        jb .startMakingNumber

        cmp al, '9'
        ja .startMakingNumber

        sub rax, '0'

		push rax
		inc rcx
		inc rsi
		jmp .getDigits
	
	.startMakingNumber:
		
		mov rbx, 1
		mov rdi, 0

	.makingNumbersLoop:	
		cmp rcx,0
		je .end
		pop rax
		mul rbx
		add rdi, rax
		mov rax, 10
		mul rbx
		mov rbx, rax
		
		dec rcx
		jmp .makingNumbersLoop

	.end:
	
		mov rax, rdi 
		
		pop rdi
		pop rdx
		pop rcx
		pop rbx

ret
;;;;;;;;;;;;;;






parseRestOfList:
    ; string pointer comes into rsi

    ; type of outcome comes out of rax (is a list or null)
    ; value of outcome comes out of rbx

    ; TODO: make this tail-call recursive by passing the place to write the value to as a parameter
    
        push rcx
        push rdx
        push rdi


        call skipSpaces

        mov al, [rsi]

        cmp al, ')'
        je .returnNull

        cmp al, 0
        je .noClosingParen

        call parse
        

        push rax
        push rbx

        
        call parseRestOfList


        pop rdx
        pop rcx

        ; now the car is in rcx:rdx
        ; cdr is in rax:rbx

        ; write the values to heap
        mov rdi, [alloc_ptr]

        mov [rdi], rcx
        mov [rdi+8], rdx
        mov [rdi+16], rax
        mov [rdi+24], rbx


        mov rax, cons_t
        mov rbx, rdi

        add qword [alloc_ptr], 32

        jmp .return

    .returnNull:
        mov byte [rsi], 0
        inc rsi

        mov rax, null_t
        mov rbx, 0
        jmp .return


    .noClosingParen:
    ; TODO: print error message
        jmp exitError


    .return:
        pop rdi
        pop rdx
        pop rcx
        
        ret

    
skipSpaces:
    ; buffer pointer comes into esi
		
		push rax
		
	.start:
		mov al, [rsi]
	
		cmp al, ' '
		je .continue
		cmp al, `\t`
		je .continue
		cmp al, `\n` ; something something line break carriage return XXX
		je .continue

        jmp .end
		
    .continue:
        mov byte [rsi], 0
		inc rsi
		
		jmp .start
		
	.end:
		pop rax

    ret

    




