/*
  Copyright (C) todo...
*/

#import <SOGoAPIUserFolder.h>

#import <GDLContentStore/GCSFolderManager.h>

@implementation SOGoAPIUserFolder

- (id) init
{
  [super init];

  return self;
}

- (void) dealloc
{
  [super dealloc];
}


- (NSDictionary *) action: (WOContext*) ctx withParam: (NSDictionary *) param
{
  /*
  Coté sogo, il faudrait un endpoint API qui retourne tous les liens caldav/cardav + leur nom lisible de l’utilisateur.
  */
NSDictionary* result;
NSArray *folders;
NSMutableArray *cardavLinks, *caldavLinks;
NSString *serverUrl, *basePath, *c_uid, *url;
GCSFolderManager *fm;
int max, i;

//Should be a user
c_uid = [[[param objectForKey: @"user"] objectForKey: @"emails"] objectAtIndex: 0];

//fetch folders
fm = [GCSFolderManager defaultFolderManager];
basePath = [NSString stringWithFormat: @"/Users/%@", c_uid];
folders = [fm listSubFoldersAtPath: basePath recursive: YES];

//Generate dav link
max = [folders count];
serverUrl = [[ctx serverURL] absoluteString];

cardavLinks = [NSMutableArray array];
caldavLinks = [NSMutableArray array];
serverUrl = [[ctx serverURL] absoluteString];
for (i = 0; i < max; i++)
{
  url = [NSString stringWithFormat: @"%@/SOGo/dav/%@/%@", serverUrl, c_uid, [folders objectAtIndex: i]];
  if([url rangeOfString:@"/Calendar/"].location == NSNotFound)
  {
    //Contacts
    [cardavLinks addObject: url];
  }
  else
  {
    //Calendar
    [caldavLinks addObject: url];
  }
}

result = [[NSDictionary alloc] initWithObjectsAndKeys:
                                  c_uid,  @"username",
                                  cardavLinks, @"contact",
                                  caldavLinks, @"calendar",
                                  nil];

[result autorelease];
return result;
}


@end /* SOGoAPIVersion */