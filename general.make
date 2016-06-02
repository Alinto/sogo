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
ADDITIONAL_OBJCFLAGS += -g -frecord-gcc-switches

