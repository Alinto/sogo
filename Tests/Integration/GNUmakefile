PROGRAM=teststrings

SRCS=teststrings.m
OBJS=$(SRCS:.m=.o)

teststrings: $(OBJS)
	$(CC) -o $@ $< $(GNUSTEP_LIBRARIES_FLAGS) -lSOGo -lgnustep-base

include $(GNUSTEP_MAKEFILES)/common.make

all: $(PROGRAM)

clean:
	rm -f $(PROGRAM) $(OBJS) *~

.m.o:
	$(CC) -o $@ -c $(GNUSTEP_HEADERS_FLAGS) $(AUXILIARY_OBJCFLAGS) $(OBJCFLAGS) $(CPPFLAGS) $<

.SUFFIXES: .m .o
