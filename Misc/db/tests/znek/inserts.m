/*
  @DISCLAIMER@
*/
// $Id$

#import <Foundation/Foundation.h>
#import <EOAccess/EOAccess.h>
#import <NGExtensions/NGExtensions.h>
#import "NSArray+random.h"


#define DEBUG 0


#define PERSON_RECORDS @"/home/znek/all-BALI.plist"


int main(int argc, char **argv, char **env) {
    NSAutoreleasePool *pool;
    EOModel             *m = nil;
    EOAdaptor           *a;
    EOAdaptorContext    *ctx;
    EOAdaptorChannel    *ch;
    NSDictionary        *conDict;
    NSUserDefaults      *ud;

    pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
    [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

    ud = [NSUserDefaults standardUserDefaults];

    conDict = [NSDictionary dictionaryWithContentsOfFile:@"connection.plist"];
    NSLog(@"condict is %@", conDict);
    
    if ((a = [EOAdaptor adaptorWithName:@"PostgreSQL72"]) == nil) {
        NSLog(@"found no PostgreSQL adaptor ..");
        exit(1);
    }

#if DEBUG
    NSLog(@"got adaptor %@", a);
#endif
    [a setConnectionDictionary:conDict];
#if DEBUG
    NSLog(@"got adaptor with condict %@", a);
#endif

    
    ctx = [a   createAdaptorContext];
    ch  = [ctx createAdaptorChannel];
    
    m = [[EOModel alloc] initWithContentsOfFile:@"inserts.eomodel"];
    if (m) {
        [a setModel:m];
        [a setConnectionDictionary:conDict];
    }
    
    
    NSLog(@"opening channel ..");
   
#if DEBUG
    [ch setDebugEnabled:YES];
#endif

    if ([ch openChannel]) {
        NSLog(@"channel is open");

#if 0
        if ([ctx beginTransaction]) {
            NSLog(@"began tx ..");
#endif            
            {
                EOSQLQualifier *q;
                NSArray *attrs;
                NSString *expr;

#if 1
                NS_DURING

                if([ctx beginTransaction]) {
                    expr = @"DROP TABLE SOGo_test";

                    if([ch evaluateExpression:expr]) {
                        if([ctx commitTransaction]) {
                            NSLog(@"DROP'ed table - committed.");
                        } else {
                            NSLog(@"couldn't commit DROP TABLE!");
                        }
                    }
                }

                NS_HANDLER
                    
                    NSLog(@"DROP table aborted - %@", [localException reason]);
                    [ctx rollbackTransaction];
                    
                NS_ENDHANDLER
#endif
                
                NS_DURING

                if([ctx beginTransaction]) {
                    expr = @"CREATE TABLE SOGo_test (c_id INT PRIMARY KEY, c_dir       VARCHAR(300) NOT NULL, c_cn VARCHAR(80) NOT NULL, c_mailto VARCHAR(120) NOT NULL);";
                    if([ch evaluateExpression:expr]) {
                        if([ctx commitTransaction]) {
                            NSLog(@"CREATE TABLE - committed");
                        } else {
                            NSLog(@"couldn't commit CREATE TABLE!");
                        }
                    }
                }
                
                NS_HANDLER

                   fprintf(stderr, "exception: %s\n", [[localException description] cString]);
                   abort();

                NS_ENDHANDLER;

                // Now for some serious business...
                if([ctx beginTransaction]) {
                    NSString    *path;
                    NSArray     *allPersonRecords;
                    unsigned    i, count;
                    EOEntity    *e;
                    NSArray     *attributes, *attributesNames;

                    path = [ud stringForKey:@"PersonRecords"];
                    if(path == nil)
                        path = PERSON_RECORDS;
                    
                    allPersonRecords = [NSArray arrayWithContentsOfFile:path];
                    NSCAssert([allPersonRecords count] != 0, @"allPersonRecords empty?!");

                    e = [m entityNamed:@"Test"];
                    attributes = [e attributesUsedForInsert];
                    attributesNames = [e attributesNamesUsedForInsert];

                    for(i = 0; i < 10000; i++) {
                        NSDictionary *pdata, *values;
                        NSMutableDictionary *row;
                        NSAutoreleasePool *lpool = [[NSAutoreleasePool alloc] init];
                        NSNumber *newPK;

                        pdata = [allPersonRecords randomObject];
#if DEBUG
                        NSLog(@"pdata: %@", pdata);
#endif
                        newPK = [NSNumber numberWithUnsignedInt:i + 1];
                        row = [pdata mutableCopy];
                        [row setObject:newPK forKey:[[e primaryKeyAttributeNames] lastObject]];
                        values = [e convertValuesToModel:row];
#if 0
                        pkey = [e primaryKeyForRow:values];
                        NSLog(@"pkey: %@", pkey);
#endif
                        if (![ch insertRow:values forEntity:e])
                            NSLog(@"Couldn't insert row!");
                        [lpool release];
                    }
                    if([ctx commitTransaction]) {
                        NSLog(@"INSERTS - committed");
                    } else {
                        NSLog(@"couldn't commit INSERTS!");
                    }
                } else {
                    NSLog(@"Couldn't begin transaction?");
                }
            }
 
#if 0
            NSLog(@"committing tx ..");
            if ([ctx commitTransaction])
                NSLog(@"  could commit.");
            else
                NSLog(@"  commit failed.");
	}
#endif
        
        NSLog(@"closing channel ..");
        [ch closeChannel];
    }

    
    [m release];
    [pool release];

    exit(0);
    return 0;
}
