section .note.GNU-stack noalloc noexec nowrite progbits

section .text
	global ft_strcmp
	ft_strcmp:
		sub rdi, 1
		sub rsi, 1
		push rbx
		.loop:
			inc rdi
			inc rsi
			mov byte al, [rdi]
			mov byte bl, [rsi]
			cmp al, bl
			jne .diff
			test al, al
			je .equal
			cmp byte [rsi], 0
			jne .loop
		.diff:
			movzx eax, al
			movzx ebx, bl
			sub eax, ebx
			pop rbx
			ret
		.equal:
			xor eax, eax
			pop rbx
			ret