/*
  @DISCLAIMER@
*/
// $Id$

#import <Foundation/Foundation.h>

#define DEBUG 0

#define ALL_RECORDS @"/home/znek/all-BALI.plist"

#ifndef MAX
#define MAX(a,b) (((a)>(b))?(a):(b))
#endif


int main(int argc, char **argv, char **env) {
    NSAutoreleasePool *pool;
    NSArray *records;
    unsigned int i, count, maxMailtoLength, maxDNLength, maxCNLength;
    NSString *longestMailto, *longestCN, *longestDN;

    pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
    [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

    records = [NSArray arrayWithContentsOfFile:ALL_RECORDS];
    count = [records count];
    maxMailtoLength = 0;
    maxDNLength = maxCNLength = 0;

    for(i = 0; i < count; i++) {
        NSDictionary *d;
        NSString *value;
        unsigned length;

	d = [records objectAtIndex:i];
        value = [d objectForKey:@"mailto"];
        length = [value length];
        maxMailtoLength = MAX(maxMailtoLength, length);
        if(length == maxMailtoLength)
            longestMailto = value;

        value = [d objectForKey:@"DIR"];
        length = [value length];
        maxDNLength = MAX(maxDNLength, length);
        if(length == maxDNLength)
            longestDN = value;

        value = [d objectForKey:@"CN"];
        length = [value length];
        maxCNLength = MAX(maxCNLength, length);
        if(length == maxCNLength)
            longestCN = value;
    }
    printf("\nTotal: %d\nMaxMailtoLength: %d\nlongest: %s\nmaxDN: %d\nlongest: %s\nmaxCN: %d\nlongest: %s\n", count, maxMailtoLength, [longestMailto cString], maxDNLength, [longestDN cString], maxCNLength, [longestCN cString]);
    [pool release];
    exit(0);
    return 0;
}
