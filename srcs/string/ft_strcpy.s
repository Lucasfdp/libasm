section .note.GNU-stack noalloc noexec nowrite progbits

section .text
	global ft_strcpy
	ft_strcpy:
		push r12
		mov rax, rdi
		sub rsi, 1
		sub rdi, 1
		_loop:
			inc rsi
			inc rdi
			mov byte r12b, [rsi]
			mov byte [rdi], r12b
			cmp byte [rsi], 0
			jne _loop
		pop r12
		ret