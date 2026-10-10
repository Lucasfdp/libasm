# libasm test harness
#
#   make test        build + run everything
#   make test ARGS="-v strlen"   run one suite, verbose
#   make valgrind    run the whole suite under valgrind, strict
#   make gdb         drop into gdb on the test binary
#   make symbols     list what libasm.a actually exports
#   make PIE=0 test  link with -no-pie (if your asm isn't position-independent)
#   make re / fclean / clean

NAME      := libasm_tests
LIB_DIR   := ..
LIB       := $(LIB_DIR)/libasm_bonus.a

CC        := gcc
CFLAGS    := -Wall -Wextra -g3 -O0
# -z noexecstack silences the "missing .note.GNU-stack section implies
# executable stack" warning. The real fix lives in your .s files — add
#   section .note.GNU-stack noalloc noexec nowrite progbits
# to each one.
LDFLAGS   := -z noexecstack

ifeq ($(PIE),0)
	CFLAGS  += -fno-pie
	LDFLAGS += -no-pie
endif

SRC       := main.c framework.c t_string.c t_io.c t_bonus.c
OBJ_DIR   := .objs
OBJ       := $(SRC:%.c=$(OBJ_DIR)/%.o)

# --whole-archive forces every member of libasm.a into the binary. Without it
# the weak references in test.h would silently resolve to NULL and every
# implemented function would be reported as "skip".
LINK_LIB  := -Wl,--whole-archive $(LIB) -Wl,--no-whole-archive

VG        := valgrind --leak-check=full --show-leak-kinds=all \
             --track-origins=yes --errors-for-leak-kinds=all \
             --error-exitcode=42 -s

# Fallback assembly, used only when the project has no Makefile of its own yet.
ASM_SRC   := $(shell find $(LIB_DIR) -maxdepth 2 -name '*.s' \
                 -not -path '$(LIB_DIR)/tests/*' \
                 -not -name 'practice*.s' 2>/dev/null | sort)

GREEN := \033[32m
YEL   := \033[33m
DIM   := \033[2m
RST   := \033[0m

.PHONY: all test valgrind gdb symbols clean fclean re lib

all: $(NAME)

test: $(NAME)
	@./$(NAME) $(ARGS)

valgrind: $(NAME)
	@$(VG) ./$(NAME) $(ARGS)

gdb: $(NAME)
	@gdb --quiet ./$(NAME)

symbols: lib
	@echo "$(DIM)symbols exported by $(LIB):$(RST)"
	@nm --defined-only $(LIB) 2>/dev/null | grep ' T ' || echo "  (none yet)"

$(NAME): $(OBJ) lib
	@$(CC) $(LDFLAGS) $(OBJ) $(LINK_LIB) -o $(NAME)
	@printf "$(GREEN)built $(NAME)$(RST)\n"

$(OBJ_DIR)/%.o: %.c test.h | $(OBJ_DIR)
	@$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR):
	@mkdir -p $(OBJ_DIR)

# Build libasm.a: prefer the project's own Makefile, fall back to assembling
# every .s we can find.
lib:
	@if [ -f $(LIB_DIR)/Makefile ]; then \
		$(MAKE) --no-print-directory -C $(LIB_DIR) bonus; \
	else \
		$(MAKE) --no-print-directory fallback-lib; \
	fi
	@if [ ! -f $(LIB) ]; then \
		printf "$(YEL)no libasm.a yet — building an empty one$(RST)\n"; \
		ar rcs $(LIB); \
	fi

.PHONY: fallback-lib
fallback-lib:
	@mkdir -p $(OBJ_DIR)/asm
	@if [ -z "$(ASM_SRC)" ]; then \
		printf "$(YEL)no .s files found in $(LIB_DIR)$(RST)\n"; \
	else \
		printf "$(DIM)assembling:$(RST) $(notdir $(ASM_SRC))\n"; \
		for f in $(ASM_SRC); do \
			nasm -f elf64 -g -F dwarf "$$f" \
				-o "$(OBJ_DIR)/asm/$$(basename $$f .s).o" || exit 1; \
		done; \
		ar rcs $(LIB) $(OBJ_DIR)/asm/*.o; \
	fi

clean:
	@rm -rf $(OBJ_DIR)

# Only our own artifacts. When the project has its own Makefile, libasm.a is ITS
# to remove — recursing into it here would be an infinite loop, because the
# project's fclean cleans us in turn.
fclean: clean
	@rm -f $(NAME)
	@if [ ! -f $(LIB_DIR)/Makefile ]; then rm -f $(LIB); fi

re: fclean all
