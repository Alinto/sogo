ifeq ($(test-uninitialized),yes)
ifeq ($(debug),yes)
ADDITIONAL_OBJCFLAGS=-O0
else
ADDITIONAL_OBJCFLAGS=-Wuninitialized
endif
endif
