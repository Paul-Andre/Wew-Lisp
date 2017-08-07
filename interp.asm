; Wew lads

SECTION .data

    heap_start: dq 0
    alloc_ptr: dq 0

    buffLen equ 80
	buff: times (buffLen+1) db 0


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




; Print what came in stdin to stdout

        mov rax, 1
        mov rdi, 1 ; stdout
        mov rsi, [heap_start]
        mov rdx, [alloc_ptr]
        sub rdx, [heap_start]
        syscall





; Exit

        mov rax, 60
        mov rdi, 0
        syscall









printNumber:
	; number comes in rax
		
		push rax
		push rbx
		push rcx
		push rdx
        push rdi


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
        mov al, `\n`
        stosb

        mov rdx, rdi
        sub rdx, buff

        mov rax, 1
        mov rdi, 1 ; stdout
        mov rsi, buff
        syscall



        pop rdi
		pop rdx
		pop rcx
		pop rbx
		pop rax
	
ret
    
