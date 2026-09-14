extern ft_strlen
extern ft_strcpy
extern malloc
extern __errno_location

section .text
	global ft_strdup
	ft_strdup:
		push r12
		mov r12, rdi
		call ft_strlen
		mov rdi, rax
		add rdi, 1
		call malloc wrt ..plt
		test rax, rax
		jz .error
		mov rdi, rax
		mov rsi, r12
		call ft_strcpy
		pop r12
		ret
		.error:
			pop r12
			ret