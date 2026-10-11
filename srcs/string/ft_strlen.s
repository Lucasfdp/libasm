section .note.GNU-stack noalloc noexec nowrite progbits

; section .text
; 	global ft_strlen
; 	ft_strlen:
; 		mov rax, -1
; 		sub rdi, 1
; 		.loop:
; 			add rax, 1
; 			add rdi, 1
; 			cmp byte [rdi], 0
; 			jne .loop
; 		ret

section .text
	global ft_strlen
	ft_strlen:
		mov rsi, rdi
		pxor xmm1, xmm1
		.align_loop:
			test rdi, 15
			jz .word_loop
			cmp byte [rdi], 0
			je .found_byte
			inc rdi
			jmp .align_loop
		.word_loop:
			movdqa xmm0, [rdi]
			pcmpeqb xmm0, xmm1
			pmovmskb eax, xmm0
			test eax, eax
			jnz .found_word
			add rdi, 16
    		jmp .word_loop
		.found_word:
			bsf eax, eax
			add rdi, rax
			sub rdi, rsi
			mov rax, rdi
			ret
		.found_byte:
			sub rdi, rsi
			mov rax, rdi
			ret
