
section .data
	newVar: db "cool"
	numVar: db 0

section .text
	global _start
	_start:
		mov r12, 0
		_loop:
			add r12, 1
			cmp r12, 9
			jne _loop
		mov rax, 1
		mov rdi, 0
		add r12, 0x30
		mov [numVar], r12b
		mov rsi, numVar
		mov rdx, 1
		syscall
		mov rax, 1
		mov rdi, 0
		mov rsi, newVar
		mov rdx, 4
		syscall
		mov rax, 60
		mov rdi, 69
		syscall
