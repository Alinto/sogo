/*
  Copyright (C) todo...
*/

#import <SOGoAPIUserFolder.h>

#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>

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

/**



{
   "calendar":[
      {
         "name":"DidyShared",
         "url":"http://127.0.0.1/SOGo/dav/sogo-tests1@example.org/Calendar/12509-67F67D00-1-3105AF40"
      },
      {
         "name":"LocalDidy",
         "url":"http://127.0.0.1/SOGo/dav/sogo-tests1@example.org/Calendar/1BC38-67B60000-1-6E4B6880"
      },
      {
         "name":"Personal Calendar",
         "url":"http://127.0.0.1/SOGo/dav/sogo-tests1@example.org/Calendar/personal"
      }
   ],
   "username":"sogo-tests1@example.org",
   "contact":[
      {
         "name":"Personal Address Book",
         "url":"http://127.0.0.1/SOGo/dav/sogo-tests1@example.org/Contacts/personal"
      }
   ]
}
**/

- (NSDictionary *) action: (WOContext*) ctx withParam: (NSDictionary *) param
{
  NSDictionary* result;
  NSArray *folders;
  NSMutableArray *cardavLinks, *caldavLinks;
  NSString *serverUrl, *basePath, *c_uid, *url;
  GCSFolderManager *fm;
  GCSFolder *folder;

  int max, i;

  //Should be a user
  c_uid = [[[param objectForKey: @"user"] objectForKey: @"emails"] objectAtIndex: 0];

  //fetch folders
  fm = [GCSFolderManager defaultFolderManager];
  basePath = [NSString stringWithFormat: @"/Users/%@", c_uid];
  folders = [fm listSubFoldersAndNamesAtPath: basePath recursive: YES];

  //Generate dav link
  max = [folders count];
  serverUrl = [[ctx serverURL] absoluteString];

  cardavLinks = [NSMutableArray array];
  caldavLinks = [NSMutableArray array];
  serverUrl = [[ctx serverURL] absoluteString];
  for (i = 0; i < max; i++)
  {
    NSMutableDictionary *folderRet;
    folderRet = [NSMutableDictionary dictionary];
    folder = [folders objectAtIndex: i];
    url = [NSString stringWithFormat: @"%@/SOGo/dav/%@/%@", serverUrl, c_uid, [folder objectForKey: @"path"]];
    [folderRet setObject: url forKey: @"url"];
    [folderRet setObject: [folder objectForKey: @"name"] forKey: @"name"];
    if([url rangeOfString:@"/Calendar/"].location == NSNotFound)
    {
      //Contacts
      [cardavLinks addObject: folderRet];
    }
    else
    {
      //Calendar
      [caldavLinks addObject: folderRet];
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