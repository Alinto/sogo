// $Id$

#include "common.h"

static void testurl(NSString *s) {
  NSURL *url;
  
  url = [NSURL URLWithString:s];
  NSLog(@"url: %@", url);
  NSLog(@"  login: %@", [url user]);
  NSLog(@"  pwd:   %@", [url password]);
}

static void test(void) {
  testurl(@"http://OGoUser:OGoPwd@localhost/OGo");
  testurl(@"postgresql://OGoUser:OGoPwd@localhost/OGo");
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  test();

  [pool release];
  return 0;
}
