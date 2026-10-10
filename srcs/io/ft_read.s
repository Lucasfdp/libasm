section .note.GNU-stack noalloc noexec nowrite progbits
extern __errno_location

section .text
	global ft_read
	ft_read:
		push r12
		push r13
		mov rax, 0
		syscall
		test rax, rax
		js .error
		pop r13
		pop r12
		ret
		.error:
			neg rax
			mov r13d, eax
			call __errno_location wrt ..plt
			mov r12, rax
			mov [r12], r13d
			mov rax, -1
			pop r13
			pop r12
			ret