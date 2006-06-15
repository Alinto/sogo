/*
  @DISCLAIMER@
*/
// $Id$

#include <EOControl/EOControl.h>
#include <NGLdap/NGLdap.h>

#define DEBUG 0

#define LDAP_HOST @"localhost"
#if DEBUG
#define LDAP_BASE_DN @"ou=Informatique,ou=SPAG,ou=DDE 32,ou=DDE,ou=melanie,ou=organisation,dc=equipement,dc=gouv,dc=fr"
#else
#define LDAP_BASE_DN @"dc=equipement,dc=gouv,dc=fr"
#endif

/*
scope = ldap.SCOPE_SUBTREE
filter = '(mineqTypeEntree=BALI)'
attrlist = ["mail", "sn", "givenName"]
*/

int main(int argc, char **argv, char **env) {
    NSAutoreleasePool *pool;
    EOQualifier *q;
    NSArray *attrs;
    NGLdapConnection *conn;
    NSEnumerator *resultEnum;
    NSMutableArray *allResults;
    id obj;
    int totalCount = 0;

    pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
    [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

    q = [EOQualifier qualifierWithQualifierFormat:@"mineqTypeEntree = BALI"];

    attrs = [[NSArray alloc] initWithObjects:@"sn", @"givenName", @"mail",
nil];

    conn = [[NGLdapConnection alloc] initWithHostName:LDAP_HOST];
    [conn setUseCache:NO];
    resultEnum = [conn deepSearchAtBaseDN:LDAP_BASE_DN
                                qualifier:q
                               attributes:attrs];

    allResults = [[NSMutableArray alloc] initWithCapacity:60000];
    while((obj = [resultEnum nextObject]) != nil) {
        NSAutoreleasePool *lpool;
        NSMutableDictionary *resultDict;
        NSDictionary *attrDict;
        NSString *dir, *cn;
        NGLdapAttribute *mail, *sn, *givenName;

        lpool = [[NSAutoreleasePool alloc] init];
        attrDict = [obj attributes];
        resultDict =
            [[NSMutableDictionary alloc] initWithCapacity:[attrDict count] + 1];
        dir = [NSString stringWithFormat:@"SOGo://%@", [obj dn]];
#if DEBUG
        NSLog(@"obj = %@", obj);
#endif
        [resultDict setObject:dir forKey:@"DIR"];
        mail = [attrDict objectForKey:@"mail"];
        [resultDict setObject:[mail stringValueAtIndex:0] forKey:@"mailto"];
        sn = [attrDict objectForKey:@"sn"];
        givenName = [attrDict objectForKey:@"givenName"];
        cn = [NSString stringWithFormat:@"%@ %@", 
                       [givenName stringValueAtIndex:0],
                       [sn stringValueAtIndex:0]];
        [resultDict setObject:cn forKey:@"CN"];
        [allResults addObject:resultDict];
        [resultDict release];
        totalCount += 1;
        if(totalCount % 10 == 0)
            printf(".");
        [lpool release];
    }

    [allResults writeToFile:@"/tmp/all.nsarray" atomically:NO];
    [allResults release];
    printf("\ndone.\n");
    [attrs release];
    [conn release];
    [pool release];
    exit(0);
    return 0;
}
