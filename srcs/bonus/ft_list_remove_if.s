section .note.GNU-stack noalloc noexec nowrite progbits
extern free

section .text
	global ft_list_remove_if
	ft_list_remove_if:
		push rbx
		push r12
		push r13
		push r14
		push r15
		test rdi, rdi
		jz .fin
		mov r12, rdi
		mov r13, rsi
		mov r14, rdx
		mov r15, rcx
		.loop:
			mov rbx, [r12]
			test rbx, rbx
			jz .fin
			mov rdi, [rbx]
			mov rsi, r13
			call r14
			test eax, eax
			jnz .keep
			mov r9, [rbx + 8]
			mov [r12], r9
			mov rdi, [rbx]
			call r15
			mov rdi, rbx
			call free wrt ..plt
			jmp .loop
		.keep:
			lea r12, [rbx + 8]
			jmp .loop
		.fin:
			pop r15
			pop r14
			pop r13
			pop r12
			pop rbx
			ret