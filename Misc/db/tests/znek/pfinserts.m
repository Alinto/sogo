/*
  @DISCLAIMER@
*/
// $Id$

#import <Foundation/Foundation.h>

#define DEBUG 0

#define ALL_RECORDS @"/home/znek/all-BALI.plist"

/*
  CREATE_TABLE personalfolderinfo (
                                  c_email     VARCHAR(128) NOT NULL, // index drauf
                                  c_tablename VARCHAR(128) NOT NULL,
                                  c_dbname    VARCHAR(128) NOT NULL,
                                  c_dbport    INT NOT NULL
                                  // kann man spaeter mit condict erweitern (user/login?)
                                  );
  */

#define PREAMBLE @"BEGIN;\n"
#define INSERT_FORMAT @"INSERT INTO personalfolderinfo VALUES ('%@', 'I%06d', 'SOGo1', 0);\n"
#define POSTAMBLE @"COMMIT;\n"


int main(int argc, char **argv, char **env) {
    NSAutoreleasePool *pool;
    NSArray *records;
    unsigned int i, count, maxLength;
    NSString *longestMailto;
    int sequence;

    pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
    [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

    records = [NSArray arrayWithContentsOfFile:ALL_RECORDS];
#if DEBUG
    count = 5;
#else
    count = [records count];
#endif
    sequence = 0;

    printf([PREAMBLE cString]);
    for(i = 0; i < count; i++) {
        NSString *format, *mailto;
        NSDictionary *d;
        d = [records objectAtIndex:i];
			
        mailto = [d objectForKey:@"mailto"];
        if([mailto rangeOfString:@"'"].location != NSNotFound) {
            NSArray *exploded;
						                
            exploded = [mailto componentsSeparatedByString:@"'"];
            mailto = [exploded componentsJoinedByString:@"\\'"];
        }
        format = [[NSString alloc] initWithFormat:INSERT_FORMAT,
					            mailto,
				                sequence++];
										        printf([format cString]);
        [format release];
	}
    printf([POSTAMBLE cString]);
    [pool release];
    exit(0);
    return 0;
}
