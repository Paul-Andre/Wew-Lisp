; Wew lads

; Define the type tags

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



SECTION .data
    genericErrorMsg: db `There was some error.\n`
	genericErrorMsgLen equ $-genericErrorMsg


SECTION .bss
    heap_start: resq 1
    program_end: resq 1

    alloc_ptr: resq 1

    buffLen equ 80
	buff: resb (buffLen+1)
    


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








mov rsi, [heap_start]
call parse

;call printNumber

call print

; Print what came in stdin to stdout

        ;mov rax, 1
        ;mov rdi, 1 ; stdout
        ;mov rsi, [heap_start]
        ;mov rdx, [program_end]
        ;sub rdx, [heap_start]
        ;syscall




; Exit

        mov rax, 60
        mov rdi, 0
        syscall



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


    





printNumber:
	; number comes in rax
		
		push rax
		push rbx
		push rcx
		push rdx
        push rdi
        push rsi


        push rax

        mov rdi, buff
        mov rcx, buffLen
        mov rax, 0
        rep stosb

        pop rax
		
        mov rdi, buff

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
        sub rdx, buff

        mov rax, 1
        mov rdi, 1 ; stdout
        mov rsi, buff
        syscall



        pop rsi
        pop rdi
		pop rdx
		pop rcx
		pop rbx
		pop rax
	
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
    
    
