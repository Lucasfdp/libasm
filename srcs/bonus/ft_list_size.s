section .note.GNU-stack noalloc noexec nowrite progbits

section .text
	global ft_list_size
	ft_list_size:
		mov rax, 0
		test rdi, rdi
		jz .fin
		.loop:
			add rax, 1
			mov rdi, [rdi + 8]
			test rdi, rdi
			jnz .loop
			.fin:
				ret
