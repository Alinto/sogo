# Macros that allow testing for GCC flag existence
try-run = $(shell set -e;                      \
	TMP="/tmp/SOGo-gcc-flags-check.$$$$.tmp";  \
	TMPO="/tmp/SOGo-gcc-flags-check.$$$$.o";   \
	if ($(1)) >/dev/null 2>&1;                 \
	then echo "$(2)";                          \
	else echo "$(3)";                          \
	fi;                                        \
	rm -f "$$TMP" "$$TMPO")

cc-option = $(call try-run,\
	$(CC) $(1) -c -x c /dev/null -o "$$TMP",$(1),$(2))

# Use GCC level 2 optimization by default
# Might be overridden below
ADDITIONAL_OBJCFLAGS=-O2
ifeq ($(test-uninitialized),yes)
ifeq ($(debug),yes)
ADDITIONAL_OBJCFLAGS=-O0
else
ADDITIONAL_OBJCFLAGS=-Wuninitialized
endif
endif
# Ensure we store in the ELF files minimal debugging
# information plus the compiler flags used; that can
# be afterwards read with:
# readelf -p .GCC.command.line /path/to/elf_file
ADDITIONAL_OBJCFLAGS += -g $(call cc-option,-frecord-gcc-switches)

