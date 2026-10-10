section .note.GNU-stack noalloc noexec nowrite progbits
extern malloc

section .text
	global ft_list_push_front
	ft_list_push_front:
		push r12
		push r13
		sub rsp, 8
		test rdi, rdi
		jz .fin
		mov r12, rdi
		mov r13, rsi
		mov rdi, 16
		call malloc wrt ..plt
		test rax, rax
		jz .fin
		mov [rax], r13
		mov rcx, [r12]
		mov [rax + 8], rcx
		mov [r12], rax
		.fin:
			add rsp, 8
			pop r13
			pop r12
			ret
