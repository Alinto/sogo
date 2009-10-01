ifeq ($(test-uninitialized),yes)
ifeq ($(debug),yes)
ADDITIONAL_OBJCFLAGS=-O1
else
ADDITIONAL_OBJCFLAGS=-Wuninitialized
endif
endif
