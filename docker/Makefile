# Convenience wrapper around run.sh. Everything here is optional — run.sh works alone.
#
# Unlike the ft_ping version there is no native-arch detection to do: libasm is
# x86_64 assembly, so the only image that exists is linux/amd64.

RUN      := ./run.sh
UNAME_M  := $(shell uname -m)
ifeq ($(filter arm64 aarch64,$(UNAME_M)),)
HOSTNOTE := native x86_64 — no emulation
else
HOSTNOTE := arm64 host — the container runs emulated
endif

.PHONY: help build rebuild shell fish check test valgrind symbols clean fix-perms

help:
	@echo "libasm docker environment  ($(HOSTNOTE))"
	@echo
	@echo "  make build         build the x86_64 image"
	@echo "  make rebuild       force a rebuild"
	@echo "  make check         verify the environment    <- run this first"
	@echo "  make shell         interactive bash shell    <- daily driver"
	@echo "  make fish          interactive fish shell"
	@echo "  make test          build + run the test suite"
	@echo "  make valgrind      run the test suite under valgrind"
	@echo "  make symbols       list what libasm.a currently exports"
	@echo "  make clean         remove the image"
	@echo "  make fix-perms     chown build artifacts back to you (Linux hosts)"

build:
	@$(RUN) --build -- true

rebuild:
	@$(RUN) --rebuild -- true

shell:
	@$(RUN)

fish:
	@$(RUN) --fish

check:
	@$(RUN) --check

test:
	@$(RUN) --test

valgrind:
	@$(RUN) --valgrind

symbols:
	@$(RUN) -- make -C tests symbols

clean:
	-docker image rm libasm-env:amd64 2>/dev/null || true

# On a Linux host the container runs as root, so anything it writes into the bind
# mount ends up root-owned on your machine. macOS/Docker Desktop maps ownership for
# you, so this is a no-op there.
fix-perms:
	@if [ "$$(uname -s)" = "Linux" ]; then \
		sudo chown -R "$$(id -u):$$(id -g)" .. && echo "ownership restored"; \
	else \
		echo "not needed on $$(uname -s)"; \
	fi
