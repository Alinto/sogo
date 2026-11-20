# GNUstep makefile

include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

TEST_TOOL = sogo-crypto-tests
$(TEST_TOOL)_OBJC_FILES = \
	TestNSDataHexDecode.m \
	../NSData+Crypto.m

$(TEST_TOOL)_C_FILES = \
	../aes.c \
	../crypt_blowfish.c \
	../lmhash.c \
	../pkcs5_pbkdf2.c

TEST_TOOL_NAME = $(TEST_TOOL)

$(TEST_TOOL)_CPPFLAGS += \
	-Wall -D_GNU_SOURCE -I..

ifeq ($(HAS_LIBRARY_ssl),yes)
$(TEST_TOOL)_CPPFLAGS += -DHAVE_OPENSSL=1
ADDITIONAL_LIB_DIRS += -lcrypto
endif

ifeq ($(HAS_LIBRARY_gnutls),yes)
$(TEST_TOOL)_CPPFLAGS += -DHAVE_GNUTLS=1
endif

ifeq ($(HAS_LIBRARY_sodium),yes)
$(TEST_TOOL)_CPPFLAGS += -DHAVE_SODIUM=1 `pkg-config --cflags libsodium`
ADDITIONAL_LIB_DIRS += `pkg-config --libs libsodium`
endif

ADDITIONAL_LIB_DIRS += -lobjc -lcrypt
ADDITIONAL_LDFLAGS += -Wl,--no-as-needed -Wl,--unresolved-symbols=ignore-in-object-files

include $(GNUSTEP_MAKEFILES)/test-tool.make
