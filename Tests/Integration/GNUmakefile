PROGRAM=teststrings

SRCS=teststrings.m
OBJS=$(SRCS:.m=.o)

teststrings: $(OBJS)
	$(CC) -o $@ $< $(GNUSTEP_LIBRARIES_FLAGS) -lgnustep-base -L../../SoObjects/SOGo/SOGo.framework -lSOGo

include $(GNUSTEP_MAKEFILES)/common.make

all: $(PROGRAM)

clean:
	rm -f $(PROGRAM) $(OBJS) *~

.m.o:
	$(CC) -o $@ -c $(GNUSTEP_HEADERS_FLAGS) $(AUXILIARY_OBJCFLAGS) $(OBJCFLAGS) $(CPPFLAGS) -I../../SoObjects $<

.SUFFIXES: .m .o
