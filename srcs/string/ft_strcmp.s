
section .text
	global ft_strcmp
	ft_strcmp:
		sub rdi, 1
		sub rsi, 1
		push rbx
		_loop:
			inc rdi
			inc rsi
			mov byte al, [rdi]
			mov byte bl, [rsi]
			cmp al, bl
			jne .diff
			test al, al
			je .equal
			cmp byte [rsi], 0
			jne _loop
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