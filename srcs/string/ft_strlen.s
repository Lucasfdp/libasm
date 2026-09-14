
section .text
	global ft_strlen
	ft_strlen:
		mov rax, -1
		sub rdi, 1
		_loop:
			add rax, 1
			add rdi, 1
			cmp byte [rdi], 0
			jne _loop
		ret
