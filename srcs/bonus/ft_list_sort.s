section .note.GNU-stack noalloc noexec nowrite progbits

section .text
	global ft_list_sort
	ft_list_sort:
		push r12
		push r13
		push r14
		push r15
		sub rsp, 8
		test rdi, rdi
		jz .fin
		mov r12, rdi
		mov r13, rsi
		.pass:
			xor r14, r14
			mov r15, [r12]
			test r15, r15
			jz .fin
		.walk:
			mov rdi, [r15]
			mov rcx, [r15 + 8]
			test rcx, rcx
			jz .endpass
			mov rsi, [rcx]
			call r13
			cmp eax, 1
			jl .adv
			mov rcx, [r15]
			mov rdx, [r15 + 8]
			mov r8, [rdx]
			mov [r15], r8
			mov [rdx], rcx
			mov r14, 1
		.adv:
			mov r15, [r15 + 8]
			jmp .walk
		.endpass:
			cmp r14, 1
			je .pass
		.fin:
			add rsp, 8
			pop r15
			pop r14
			pop r13
			pop r12
			ret