# =============================================================================
#  libasm
#
#  Source layout:
#    includes/       libasm.h — the C prototypes your test drivers include
#    srcs/string/    ft_strlen ft_strcpy ft_strcmp ft_strdup
#    srcs/io/        ft_write ft_read           (errno via __errno_location)
#    srcs/bonus/     ft_atoi_base ft_list_*     (built only by `make bonus`)
#    tests/          the C test harness, one binary, weak-linked
#    docker/         x86_64 container — see docker/README.md
#
#  Sources are DISCOVERED, not listed: adding a .s anywhere under srcs/ picks
#  it up with no edit here. Object files mirror the source tree under obj/.
#
#  The deliverable is a STATIC LIBRARY, not a program. There is no `make run`:
#  nothing here has a main(). `make test` links the archive into the C harness
#  in tests/ and that is what you actually execute.
# =============================================================================

NAME		:=	libasm.a
BONUS_NAME	:=	libasm_bonus.a

# ==========================
# Assembler + compiler detection
# ==========================
# Same reasoning as ft_ping, one layer deeper. A missing tool makes the compile
# rule die with a bare
#
#     make: *** [Makefile:NN: obj/srcs/string/ft_strlen.o] Error 127
#
# 127 is the shell's code for "command not found", but make reports the TARGET
# rather than the missing command, so the message reads as though the object
# file were the problem. It is not: the assembler is.
#
# nasm is non-negotiable — the subject mandates it, and gas syntax is a
# different language. A command-line override always wins:  make AS=/path/nasm
#
# Note the `origin` guard rather than a plain `?=`. make ships a built-in
# default of AS = as, and a built-in default counts as "already defined", so
# `AS ?= nasm` silently leaves you assembling with GNU as — which then dies on
# nasm's flags with "as: unrecognized option '-F'". Testing origin replaces
# only make's own default and still yields to your command line or environment.
ifeq ($(origin AS),default)
AS			:=	nasm
endif

# $(error) fires at parse time, which would take `make env` down with it — and
# env is the target that exists to diagnose exactly this. So the check is skipped
# for the goals that do not touch the assembler.
DIAG_GOALS	:=	env help list cloc shell check-env clean fclean
ifeq ($(filter $(DIAG_GOALS),$(MAKECMDGOALS)),)
ifeq ($(shell command -v $(AS) 2>/dev/null),)
$(error No assembler found - looked for '$(AS)' on your PATH. \
Install it with `sudo apt install nasm` (Debian/Ubuntu) or `brew install nasm` \
(macOS), or point this at yours: make AS=/path/to/nasm. \
Easier: run everything in the container — `make -C docker shell`)
endif
endif

# cc is only needed to LINK and to build the test harness. Assembling works
# without it, so this is a warning at `make env` time rather than a hard error.
CC			:=	$(firstword $(foreach c,cc gcc clang,\
					$(if $(shell command -v $(c) 2>/dev/null),$(c))))

# -f elf64   the subject's output format; nothing else links on Linux x86_64
# -g -F dwarf  debug info, so gdb can show you your own source lines rather
#            than raw disassembly. Costs nothing in the shipped .a.
# -MD/-MP    dependency files, for when you start using %include
ASFLAGS		:=	-f elf64 -g -F dwarf
ARFLAGS		:=	rcs

SRC_DIR		:=	srcs
BONUS_DIR	:=	$(SRC_DIR)/bonus
TEST_DIR	:=	tests
OBJ_DIR		:=	obj
INC_DIR		:=	includes

# ==========================
# Source discovery
# ==========================
# 2>/dev/null so a fresh clone with no srcs/ yet reports "0 sources" via
# `make env` instead of spraying find errors over every target.
#
# practice*.s is skipped on purpose: scratch files experimenting with _start
# would collide with the C runtime's entry point once linked into the harness.
ALL_SRCS	:=	$(shell find $(SRC_DIR) -name '*.s' -not -name 'practice*.s' 2>/dev/null | sort)
BONUS_SRCS	:=	$(filter $(BONUS_DIR)/%,$(ALL_SRCS))
SRCS		:=	$(filter-out $(BONUS_DIR)/%,$(ALL_SRCS))

OBJS		:=	$(SRCS:%.s=$(OBJ_DIR)/%.o)
BONUS_OBJS	:=	$(BONUS_SRCS:%.s=$(OBJ_DIR)/%.o)

TOTAL		:=	$(words $(SRCS))
BONUS_TOTAL	:=	$(words $(BONUS_SRCS))

# The progress bar needs the right denominator. A target-specific variable would
# not do it: the bar is printed from the pattern rule, and the counter is an
# $(eval) of global state, so the value has to be settled before any recipe runs.
ifneq ($(filter bonus,$(MAKECMDGOALS)),)
TOTAL		:=	$(words $(SRCS) $(BONUS_SRCS))
endif
COMPILED	:=	0
MAKEFLAGS	+=	--no-print-directory

# The banner clears the screen, which is charming at the top level and
# vandalism when tests/Makefile calls this Makefile mid-run. MAKELEVEL is 0
# only when you invoked make yourself.
ifeq ($(MAKELEVEL),0)
TOPLEVEL	:=	1
endif

UNAME_S		:=	$(shell uname -s)

# ==========================
# Colours
# ==========================
GREEN		= \033[0;32m
BLUE		= \033[0;34m
CYAN		= \033[0;36m
YELLOW		= \033[0;33m
RED			= \033[0;31m
MAGENTA		= \033[0;35m
BOLD		= \033[1m
RESET		= \033[0m

# ==========================
# Targets
# ==========================
all: $(NAME)

$(NAME): $(OBJS)
	@if [ -z "$(OBJS)" ]; then \
		printf "$(YELLOW)$(BOLD)  no .s files under $(SRC_DIR)/ yet — creating an empty $(NAME)$(RESET)\n"; \
		printf "$(YELLOW)  run 'make env' to see the layout this Makefile expects$(RESET)\n\n"; \
	fi
	@$(AR) $(ARFLAGS) $(NAME) $(OBJS)
	@if [ -n "$(TOPLEVEL)" ]; then $(MAKE) banner; fi
	@printf "$(GREEN)$(BOLD) [$(NAME) built — $(words $(OBJS)) object(s)]$(RESET)\n\n"
	@$(MAKE) warn-host

bonus: $(OBJS) $(BONUS_OBJS)
	@$(AR) $(ARFLAGS) $(BONUS_NAME) $(OBJS) $(BONUS_OBJS)
	@printf "$(GREEN)$(BOLD) [$(BONUS_NAME) built — $(words $(OBJS)) + $(words $(BONUS_OBJS)) object(s)]$(RESET)\n\n"

# Assemble with progress bar. The mkdir handles the mirrored obj/ subtree,
# so a new srcs/<module>/ directory needs no rule of its own.
$(OBJ_DIR)/%.o: %.s
	@mkdir -p $(dir $@)
	@$(eval COMPILED := $(shell echo $$(($(COMPILED) + 1))))
	@$(eval PCT := $(shell echo $$(($(COMPILED) * 100 / $(TOTAL)))))
	@$(eval FILLED := $(shell if [ $(COMPILED) -ge $(TOTAL) ]; then echo 20; else echo $$(($(COMPILED) * 20 / $(TOTAL))); fi))
	@$(eval EMPTY := $(shell echo $$(( 20 - $(FILLED)))))
	@printf "\r$(CYAN)  Assembling $(BOLD)%-30s$(RESET)$(CYAN) [" "$(notdir $<)"
	@i=0; while [ $$i -lt $(FILLED) ]; do printf "$(GREEN)█$(RESET)"; i=$$((i+1)); done
	@i=0; while [ $$i -lt $(EMPTY) ]; do printf "░"; i=$$((i+1)); done
	@printf "$(CYAN)] $(BOLD)%3d%%$(RESET)" $(PCT)
	@$(AS) $(ASFLAGS) -MD $(@:.o=.d) -MP $< -o $@

# ==========================
# Tests
# ==========================
# The harness lives in tests/ and links $(NAME) with --whole-archive. Every
# ft_* is declared weak there, so functions you have not written yet report
# "skip" rather than failing to link — the suite is useful from day one.
test: $(NAME)
	@printf "$(YELLOW)$(BOLD)\n  Running the test suite...$(RESET)\n\n"
	@$(MAKE) -C $(TEST_DIR) test ARGS="$(ARGS)"

# ==========================
# Valgrind
# ==========================
# No sudo here, unlike ft_ping: a static library needs no privileges. ft_strdup
# is the function this actually grades — everything else is leak-free by
# construction.
valgrind: $(NAME)
	@printf "$(YELLOW)$(BOLD)\n  Running the test suite under valgrind...$(RESET)\n\n"
	@$(MAKE) -C $(TEST_DIR) valgrind ARGS="$(ARGS)"

# ==========================
# Debug build
# ==========================
# For assembly "debug" means the harness, not the .a: nasm already emits DWARF
# above. ASan on the C driver catches overruns your asm causes in buffers the
# driver owns, and it works under emulation where valgrind often does not.
debug: fclean
	@$(MAKE) $(NAME)
	@$(MAKE) -C $(TEST_DIR) fclean
	@$(MAKE) -C $(TEST_DIR) CFLAGS="-Wall -Wextra -g3 -O0 -fsanitize=address" \
		LDFLAGS="-z noexecstack -fsanitize=address" test ARGS="$(ARGS)"
	@printf "$(RED)$(BOLD)  [Debug run with ASan complete]$(RESET)\n\n"

# ==========================
# Debugger
# ==========================
# Where ft_ping had `make run`, a library has nothing to run. This is the
# equivalent daily-driver target: gdb on the test binary, Intel syntax, ready
# for `layout regs` and `si`.
gdb: $(NAME)
	@$(MAKE) -C $(TEST_DIR) gdb

# ==========================
# Symbols and disassembly
# ==========================
symbols: $(NAME)
	@printf "$(CYAN)$(BOLD)\n  Symbols exported by $(NAME)$(RESET)\n\n"
	@nm --defined-only $(NAME) 2>/dev/null | grep ' T ' | sort -k3 | sed 's/^/    /' \
		|| printf "    $(YELLOW)(none yet)$(RESET)\n"
	@printf "$(CYAN)$(BOLD)\n  Undefined (what you call out to)$(RESET)\n\n"
	@nm --undefined-only $(NAME) 2>/dev/null | awk '$$1=="U"{print $$2}' | sort -u \
		| sed 's/^/    /' | grep . || printf "    $(YELLOW)(nothing — pure asm)$(RESET)\n"
	@printf "\n"

# Usage: make disasm FN=ft_strlen   (or FILE=obj/srcs/string/ft_strlen.o)
FN			?=
FILE		?=	$(NAME)
disasm: $(NAME)
	@printf "$(CYAN)$(BOLD)\n  Disassembly of $(FILE)$(if $(FN), — $(FN))$(RESET)\n\n"
	@objdump -d -M intel --no-show-raw-insn $(FILE) \
		| { if [ -n "$(FN)" ]; then awk '/<$(FN)>:/,/^$$/'; else cat; fi; } \
		| sed 's/^/    /'
	@printf "\n"

# ==========================
# Strict assembly check
# ==========================
# nasm's equivalent of ft_ping's -Wpedantic pass. -w+all turns on every warning
# class; -Werror makes them fatal. Also audits the one thing the linker will
# nag about forever if you skip it.
check: fclean
	@printf "$(MAGENTA)$(BOLD)\n  Strict assembly pass (-w+all -Werror)$(RESET)\n\n"
	@$(MAKE) ASFLAGS="$(ASFLAGS) -w+all -Werror" $(NAME)
	@printf "$(MAGENTA)$(BOLD)  .note.GNU-stack audit$(RESET)\n\n"
	@missing=0; for f in $(SRCS); do \
		if ! grep -q 'note.GNU-stack' "$$f"; then \
			printf "    $(YELLOW)-$(RESET) %s\n" "$$f"; missing=1; \
		fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
		printf "\n    add this line to each file above, or the linker warns that\n"; \
		printf "    your object implies an executable stack:\n\n"; \
		printf "      $(CYAN)section .note.GNU-stack noalloc noexec nowrite progbits$(RESET)\n\n"; \
	else \
		printf "    $(GREEN)✓$(RESET) every source declares a non-executable stack\n\n"; \
	fi

# ==========================
# Container
# ==========================
# libasm is x86_64 assembly; on an Apple Silicon Mac nothing here links or runs
# natively. These are shortcuts into docker/, which is where the real work
# happens. See docker/README.md.
shell:
	@$(MAKE) -C docker shell

check-env:
	@$(MAKE) -C docker check

# ==========================
# Toolchain report
# ==========================
# Run this first on any machine that will not build. It answers the questions a
# bare "Error 127" cannot, plus the one question unique to this project: can
# this machine actually RUN what it assembles?
env:
	@printf "$(CYAN)$(BOLD)\n  Toolchain$(RESET)\n\n"
	@printf "    %-14s %s\n" "assembler" "$(AS)"
	@printf "    %-14s %s\n" "path"      "$$(command -v $(AS) 2>/dev/null || echo '(not found)')"
	@printf "    %-14s %s\n" "version"   "$$($(AS) -v 2>/dev/null || echo '(unknown)')"
	@printf "    %-14s %s\n" "compiler"  "$(CC)$(if $(CC),, (none found — tests cannot link))"
	@printf "    %-14s %s\n" "ar"        "$$(command -v $(AR) 2>/dev/null || echo '(not found)')"
	@printf "    %-14s %s\n" "make"      "$$($(MAKE) --version 2>/dev/null | head -1)"
	@printf "    %-14s %s\n" "uname"     "$$(uname -srm)"
	@printf "$(CYAN)$(BOLD)\n  Can this machine run what it assembles?$(RESET)\n\n"
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
		printf "    $(YELLOW)no$(RESET) — macOS. nasm can emit elf64 objects here, but they\n"; \
		printf "         cannot be linked or executed: Linux ELF and Linux syscalls\n"; \
		printf "         are not a thing macOS does. Use the container:\n\n"; \
		printf "           $(CYAN)make -C docker build && make -C docker check$(RESET)\n"; \
		printf "           $(CYAN)make -C docker shell$(RESET)\n\n"; \
	elif [ "$$(uname -m)" != "x86_64" ]; then \
		printf "    $(RED)no$(RESET) — this is $$(uname -m), and libasm is x86_64 assembly.\n\n"; \
	else \
		printf "    $(GREEN)yes$(RESET) — x86_64 Linux.\n\n"; \
	fi
	@printf "$(CYAN)$(BOLD)  Optional tools$(RESET)\n\n"
	@for t in valgrind gdb objdump nm readelf strace docker clear; do \
		p=$$(command -v $$t 2>/dev/null); \
		if [ -n "$$p" ]; then \
			printf "    $(GREEN)✓$(RESET) %-12s %s\n" "$$t" "$$p"; \
		else \
			printf "    $(YELLOW)-$(RESET) %-12s (not installed)\n" "$$t"; \
		fi; \
	done
	@printf "$(CYAN)$(BOLD)\n  Sources found$(RESET)\n\n"
	@printf "    %-22s %s\n" ".s under $(SRC_DIR)/"      "$(TOTAL)"
	@printf "    %-22s %s\n" ".s under $(BONUS_DIR)/" "$(BONUS_TOTAL)"
	@if [ "$(TOTAL)" -eq 0 ]; then \
		printf "\n    $(RED)no sources found$(RESET) — either you are not in the repo root,\n"; \
		printf "    or you have not created the layout yet:\n\n"; \
		printf "      $(CYAN)mkdir -p $(SRC_DIR)/string $(SRC_DIR)/io $(BONUS_DIR) $(INC_DIR)$(RESET)\n"; \
	fi
	@printf "\n"

# ==========================
# Count lines of code
# ==========================
cloc:
	@printf "$(CYAN)$(BOLD)\n  Lines of assembly:$(RESET)\n\n"
	@find $(SRC_DIR) -name "*.s" 2>/dev/null | xargs wc -l 2>/dev/null | sort -rn | head -30
	@printf "$(CYAN)$(BOLD)\n  Lines of C (harness + headers):$(RESET)\n\n"
	@find $(TEST_DIR) $(INC_DIR) \( -name "*.c" -o -name "*.h" \) 2>/dev/null \
		| xargs wc -l 2>/dev/null | sort -rn | head -20
	@printf "\n"

# ==========================
# Show the source tree
# ==========================
list:
	@printf "$(CYAN)$(BOLD)\n  Mandatory ($(TOTAL) files):$(RESET)\n"
	@for f in $(SRCS); do printf "    $(GREEN)→$(RESET) $$f\n"; done
	@printf "$(CYAN)$(BOLD)\n  Bonus ($(BONUS_TOTAL) files):$(RESET)\n"
	@for f in $(BONUS_SRCS); do printf "    $(MAGENTA)→$(RESET) $$f\n"; done
	@printf "$(CYAN)$(BOLD)\n  Headers:$(RESET)\n"
	@for f in $(INC_DIR)/*.h; do [ -e "$$f" ] && printf "    $(BLUE)→$(RESET) $$f\n"; done
	@printf "$(CYAN)$(BOLD)\n  Harness:$(RESET)\n"
	@for f in $(TEST_DIR)/*.c $(TEST_DIR)/*.h; do [ -e "$$f" ] && printf "    $(YELLOW)→$(RESET) $$f\n"; done
	@printf "\n"

# ==========================
# Host warning
# ==========================
# Printed after a successful build on a machine that cannot run the result, so
# you find out now rather than when the linker rejects a Mach-O/ELF mix.
warn-host:
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
		printf "$(YELLOW)$(BOLD)  note:$(RESET) built on macOS. These are Linux ELF objects — they will\n"; \
		printf "        not link or run here. Test them in the container:\n"; \
		printf "        $(CYAN)make -C docker check && make -C docker test$(RESET)\n\n"; \
	fi

# ==========================
# Push to GitHub
# ==========================
# Usage: make push MSG="commit message"
MSG			?=	update: $(shell date "+%Y-%m-%d %H:%M")
BRANCH		:=	$(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)

push:
	@printf "$(YELLOW)$(BOLD)\n  Pushing to GitHub ($(BRANCH))...$(RESET)\n\n"
	@git add -A
	@if git diff --cached --quiet; then \
		printf "$(CYAN)  Nothing to commit, pushing anyway...$(RESET)\n"; \
	else \
		git commit -m "$(MSG)"; \
	fi
	@git push origin $(BRANCH)
	@printf "$(GREEN)$(BOLD)\n  [Pushed to $(BRANCH)]$(RESET)\n\n"

# ==========================
# Banner
# ==========================
banner:
	@# `clear` lives in ncurses-bin, which a minimal VM may not have - and a
	@# missing command here would fail the build with the same Error 127 the
	@# assembler check above exists to explain. Skip it rather than die for a
	@# cosmetic reason.
	@if [ -t 1 ] && [ -n "$$TERM" ] && command -v clear >/dev/null 2>&1; then clear; fi
	@printf "\n$(CYAN)"
	@sleep 0.05
	@printf "%s\n" "    ___ __                       "
	@sleep 0.15
	@printf "%s\n" "   / (_) /_  ____ __________ ___ "
	@sleep 0.15
	@printf "%s\n" "  / / / __ \\/ __ \`/ ___/ __ \`__ \\"
	@sleep 0.15
	@printf "%s\n" " / / / /_/ / /_/ (__  ) / / / / /"
	@sleep 0.15
	@printf "%s\n" "/_/_/_.___/\\__,_/____/_/ /_/ /_/ "
	@printf "$(RESET)\n"

# ==========================
# Clean
# ==========================
clean:
	@rm -rf $(OBJ_DIR)
	@$(MAKE) -C $(TEST_DIR) clean 2>/dev/null || true
	@printf "$(BLUE)\n  Cleansed$(RESET)\n"

fclean:
	@rm -rf $(OBJ_DIR)
	@rm -f $(NAME) $(BONUS_NAME)
	@$(MAKE) -C $(TEST_DIR) fclean 2>/dev/null || true
	@printf "$(BLUE)  More Cleansed$(RESET)\n\n"

re: fclean all

-include $(OBJS:.o=.d) $(BONUS_OBJS:.o=.d)

# ==========================
# Help
# ==========================
help:
	@printf "\n$(CYAN)$(BOLD)  libasm — available commands$(RESET)\n\n"
	@printf "  $(GREEN)make$(RESET)                  — assemble srcs/ into $(NAME)\n"
	@printf "  $(GREEN)make bonus$(RESET)            — build $(BONUS_NAME) (mandatory + bonus)\n"
	@printf "  $(GREEN)make re$(RESET)               — clean and rebuild\n"
	@printf "  $(GREEN)make clean$(RESET)            — remove object files\n"
	@printf "  $(GREEN)make fclean$(RESET)           — remove objects, archives and test binaries\n"
	@printf "  $(GREEN)make test$(RESET)             — build and run the test harness (pass ARGS=\"-v strlen\")\n"
	@printf "  $(GREEN)make valgrind$(RESET)         — run the harness under valgrind (no sudo needed)\n"
	@printf "  $(GREEN)make debug$(RESET)            — rerun the harness with AddressSanitizer\n"
	@printf "  $(GREEN)make gdb$(RESET)              — open gdb on the test binary\n"
	@printf "  $(GREEN)make symbols$(RESET)          — what $(NAME) exports, and what it calls out to\n"
	@printf "  $(GREEN)make disasm$(RESET)           — disassemble, Intel syntax (pass FN=ft_strlen)\n"
	@printf "  $(GREEN)make check$(RESET)            — strict nasm warnings + .note.GNU-stack audit\n"
	@printf "  $(GREEN)make env$(RESET)              — report the toolchain (run this if the build fails)\n"
	@printf "  $(GREEN)make shell$(RESET)            — open a shell in the x86_64 container\n"
	@printf "  $(GREEN)make check-env$(RESET)        — verify the container (docker/check-env.sh)\n"
	@printf "  $(GREEN)make cloc$(RESET)             — count lines per file\n"
	@printf "  $(GREEN)make list$(RESET)             — list the source tree\n"
	@printf "  $(GREEN)make push$(RESET)             — commit and push to GitHub (pass MSG=\"...\")\n"
	@printf "  $(GREEN)make help$(RESET)             — show this message\n"
	@printf "\n$(CYAN)  Usage from C:$(RESET)\n"
	@printf "  $(YELLOW)gcc main.c $(NAME) -o prog$(RESET)\n\n"

.PHONY: all bonus test valgrind debug gdb symbols disasm check shell check-env \
	env cloc list warn-host push banner clean fclean re help
