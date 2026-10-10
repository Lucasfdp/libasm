section .note.GNU-stack noalloc noexec nowrite progbits

section .text
	global ft_atoi_base
	ft_atoi_base:
		xor eax, eax
		.bsloop:
			movzx edx, byte [rsi + rax]
			test dl, dl
			jz .done
			cmp dl, '+'
			je .err
			cmp dl, '-'
			je .err
			cmp dl, ' '
			je .err
			cmp dl, 9
			jb .notspace
			cmp dl, 13
			jbe .err
		.notspace:
			xor ecx, ecx
		.dup:
			cmp rcx, rax
			jae .next
			cmp dl, [rsi + rcx]
			je .err
			add rcx, 1
			jmp .dup
		.next:
			add rax, 1
			jmp .bsloop
		.done:
			cmp rax, 2
			jb .err
			mov r8, rax
		.skipws:
			movzx r9d, byte [rdi]
			cmp r9b, ' '
			je .wsadv
			cmp r9b, 9
			jb .skipsigns
			cmp r9b, 13
			ja .skipsigns
		.wsadv:
			add rdi, 1
			jmp .skipws
		.skipsigns:
			mov r10, 1
		.signsloop:
			movzx r9d, byte [rdi]
			cmp r9b, '+'
			je .signsadv
			cmp r9b, '-'
			jne .calcnum
			neg r10
		.signsadv:
			add rdi, 1
			jmp .signsloop
		.calcnum:
			xor eax, eax
		.digits:
			movzx r9d, byte [rdi]
			xor ecx, ecx
		.findnum:
			cmp rcx, r8
			je .finish
			cmp r9b, [rsi + rcx]
			je .foundnum
			add rcx, 1
			jmp .findnum
		.foundnum:
			imul rax, r8
			add rax, rcx
			add rdi, 1
			jmp .digits
		.finish:
			imul rax, r10
			ret
		.err:
			xor eax, eax
			ret