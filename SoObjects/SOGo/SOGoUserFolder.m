/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoClassSecurityInfo.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <DOM/DOMDocument.h>
#import <DOM/DOMNode.h>
#import <DOM/DOMProtocols.h>
#import <SaxObjC/SaxObjC.h>
#import <SaxObjC/XMLNamespaces.h>

#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoFreeBusyObject.h>
#import <Appointments/SOGoCalendarProxy.h>
#import <Contacts/SOGoContactFolders.h>
#import <Mailer/SOGoMailAccounts.h>

#import <UI/SOGoUI/UIxComponent.h>

#import "NSArray+Utilities.h"
#import "NSDictionary+Utilities.h"
#import "LDAPUserManager.h"
#import "SOGoPermissions.h"
#import "SOGoUser.h"
#import "WORequest+SOGo.h"

#import "SOGoUserFolder.h"

static NSString *LDAPContactInfoAttribute = nil;

@implementation SOGoUserFolder

+ (void) initialize
{
  NSUserDefaults *ud;

  if (!LDAPContactInfoAttribute)
    {
      ud = [NSUserDefaults standardUserDefaults];
      LDAPContactInfoAttribute
	= [ud stringForKey: @"SOGoLDAPContactInfoAttribute"];
      [LDAPContactInfoAttribute retain];
    }
}

/* hierarchy */

- (NSArray *) toManyRelationshipKeys
{
  NSMutableArray *children;
  SOGoUser *currentUser;

  children = [NSMutableArray arrayWithCapacity: 4];

  currentUser = [context activeUser];
  if ([currentUser canAccessModule: @"Calendar"])
    {
      [children addObject: @"Calendar"];
      /* support for caldav-proxy, which is currently limited to iCal but may
         be enabled for others later, once we sort out the consistency between
         subscribe folders and "proxy collections". */
      if ([[context request] isICal])
        {
          [children addObject: @"calendar-proxy-write"];
          [children addObject: @"calendar-proxy-read"];
        }
    }
  [children addObject: @"Contacts"];
  if ([currentUser canAccessModule: @"Mail"])
    [children addObject: @"Mail"];
  // [children addObject: @"Preferences"];

  return children;
}

/* ownership */

- (NSString *) ownerInContext: (WOContext *) _ctx
{
  SOGoUser *ownerUser;

  if (!owner)
    {
      ownerUser = [SOGoUser userWithLogin: nameInContainer roles: nil];
      owner = [ownerUser login];
    }

  return owner;
}

/* looking up shared objects */

- (SOGoUserFolder *) lookupUserFolder
{
  return self;
}

- (NSDictionary *) _parseCollectionFilters: (id <DOMDocument>) parentNode
{
  id<DOMNodeList> children;
  NGDOMNode *node;
  NSMutableDictionary *filter;
  NSString *componentName;
  unsigned int count, max;

  filter = [NSMutableDictionary dictionaryWithCapacity: 2];
  children = [parentNode getElementsByTagName: @"prop-match"];
  max = [(NSArray *)children count];
  for (count = 0; count < max; count++)
    {
      node = [children objectAtIndex: count];
      componentName = [[(id<DOMElement>)node attribute: @"name"]
                        lowercaseString];
      [filter setObject: [node textValue] forKey: componentName];
    }

  return filter;
}

- (NSArray *) _subFoldersFromFolder: (SOGoParentFolder *) parentFolder
{
  NSMutableArray *folders;
  NSEnumerator *subfolders;
  SOGoFolder *currentFolder;
  NSString *folderName, *folderOwner;
  NSMutableDictionary *currentDictionary;
  SoSecurityManager *securityManager;

  folderOwner = [parentFolder ownerInContext: context];
  securityManager = [SoSecurityManager sharedSecurityManager];

  folders = [NSMutableArray array];

  subfolders = [[parentFolder subFolders] objectEnumerator];
  while ((currentFolder = [subfolders nextObject]))
    {
      if (![securityManager validatePermission: SOGoPerm_AccessObject
			    onObject: currentFolder inContext: context]
	  && [[currentFolder ownerInContext: context]
	       isEqualToString: folderOwner])
	{
	  folderName = [NSString stringWithFormat: @"/%@/%@",
				 [parentFolder nameInContainer],
				 [currentFolder nameInContainer]];
	  currentDictionary
	    = [NSMutableDictionary dictionaryWithCapacity: 3];
	  [currentDictionary setObject: [currentFolder displayName]
			     forKey: @"displayName"];
	  [currentDictionary setObject: folderName forKey: @"name"];
	  [currentDictionary setObject: folderOwner forKey: @"owner"];
	  [currentDictionary setObject: [currentFolder folderType]
			     forKey: @"type"];
	  [folders addObject: currentDictionary];
	}
    }

  return folders;
}

- (NSArray *) foldersOfType: (NSString *) folderType
		     forUID: (NSString *) uid
{
  NSObject *userFolder;
  SOGoParentFolder *parentFolder;
  NSMutableArray *folders;

  folders = [NSMutableArray array];

  userFolder = [container lookupName: uid inContext: context acquire: NO];

  if ([folderType length] == 0 || [folderType isEqualToString: @"calendar"])
    {
      parentFolder = [userFolder lookupName: @"Calendar"
				 inContext: context acquire: NO];
      [folders
	addObjectsFromArray: [self _subFoldersFromFolder: parentFolder]];
    }
  if ([folderType length] == 0 || [folderType isEqualToString: @"contact"])
    {
      parentFolder = [userFolder lookupName: @"Contacts"
				 inContext: context acquire: NO];
      [folders
	addObjectsFromArray: [self _subFoldersFromFolder: parentFolder]];
    }

  return folders;
}

- (NSDictionary *) foldersOfType: (NSString *) type
		     matchingUID: (NSString *) uid
{
  NSArray *contacts, *folders;
  NSEnumerator *enumerator;
  NSDictionary *contact;
  NSMutableDictionary *results;

  results = [NSMutableDictionary dictionary];

  contacts
    = [[LDAPUserManager sharedUserManager] fetchUsersMatching: uid];
  enumerator = [contacts objectEnumerator];
  while ((contact = [enumerator nextObject]))
    {
      uid = [contact objectForKey: @"c_uid"];
      folders = [self foldersOfType: type
		      forUID: [contact objectForKey: @"c_uid"]];
      [results setObject: folders forKey: contact];
    }

  return results;
}

- (NSArray *) davResourceType
{
  NSMutableArray *rType;

  rType = [NSMutableArray arrayWithArray: [super davResourceType]];
  [rType addObject: @"principal"];

  return rType;
}

- (void) _appendFolders: (NSArray *) folders
	     toResponse: (WOResponse *) r
{
  NSDictionary *currentFolder;
  NSString *baseHREF, *data;
  NSEnumerator *foldersEnum;
  SOGoUser *ownerUser;

  baseHREF = [[container davURL] absoluteString];
  if ([baseHREF hasSuffix: @"/"])
    baseHREF = [baseHREF substringToIndex: [baseHREF length] - 1];
  foldersEnum = [folders objectEnumerator];
  while ((currentFolder = [foldersEnum nextObject]))
    {
      [r appendContentString: @"<D:response><D:href>"];
      data = [NSString stringWithFormat: @"%@/%@%@/", baseHREF,
		       [currentFolder objectForKey: @"owner"],
		       [currentFolder objectForKey: @"name"]];
      [r appendContentString: data];
      [r appendContentString: @"</D:href><D:propstat>"];
      [r appendContentString: @"<D:status>HTTP/1.1 200 OK</D:status>"];
      [r appendContentString: @"<D:prop><D:displayname>"];
      data = [currentFolder objectForKey: @"displayName"];
      [r appendContentString: [data stringByEscapingXMLString]];
      [r appendContentString: @"</D:displayname></D:prop></D:propstat>"];

      /* Remove this once extensions 0.8x are no longer used */
      data = [NSString stringWithFormat: @"<D:owner>%@/%@</D:owner>", baseHREF,
		       [currentFolder objectForKey: @"owner"]];
      [r appendContentString: data];

      [r appendContentString: @"<ownerdisplayname>"];

      ownerUser = [SOGoUser userWithLogin: [currentFolder objectForKey: @"owner"]
			    roles: nil];
      data = [ownerUser cn];
      [r appendContentString: [data stringByEscapingXMLString]];
      [r appendContentString: @"</ownerdisplayname>"];

      [r appendContentString: @"<D:displayname>"];
      data = [currentFolder objectForKey: @"displayName"];
      [r appendContentString: [data stringByEscapingXMLString]];
      [r appendContentString: @"</D:displayname>"];
      /* end of temporary compatibility hack */

      [r appendContentString: @"</D:response>"];
    }
}

/* This method takes a user principal and converts it to a potential username.
   The old form using "dav/users/XXX" is also supported. */
- (NSString *) _userFromDAVuser: (NSString *) davOwnerMatch
{
  NSRange match;
  NSString *user;

  match = [davOwnerMatch rangeOfString: @"/SOGo/dav/users/"];
  if (match.location == NSNotFound)
    match = [davOwnerMatch rangeOfString: @"/SOGo/dav/"];
  if (match.location != NSNotFound)
    {
      user = [davOwnerMatch substringFromIndex: NSMaxRange (match)];
      match = [user rangeOfString: @"/"];
      if (match.location != NSNotFound)
	user = [user substringToIndex: match.location];
    }
  else
    user = nil;

  return user;
}

- (NSArray *) _searchDavOwners: (NSString *) davOwnerMatch
{
  NSArray *users, *owners;
  NSString *ownerMatch;
  LDAPUserManager *um;

  owners = [NSMutableArray array];
  if (davOwnerMatch)
    {
      ownerMatch = [self _userFromDAVuser: davOwnerMatch];
      um = [LDAPUserManager sharedUserManager];
      users = [[um fetchUsersMatching: ownerMatch]
		 sortedArrayUsingSelector: @selector (caseInsensitiveDisplayNameCompare:)];
      owners = [users objectsForKey: @"c_uid" notFoundMarker: nil];
    }
  else
    owners = [NSArray arrayWithObject: [self ownerInContext: nil]];

  return owners;
}

- (void) _appendFoldersOfType: (NSString *) folderType
	     ofOwnersMatching: (NSString *) ownerMatch
		   toResponse: (WOResponse *) r
{
  NSString *currentOwner;
  NSEnumerator *owners;
  NSArray *folders;

  owners = [[self _searchDavOwners: ownerMatch] objectEnumerator];
  while ((currentOwner = [owners nextObject]))
    {
      folders = [self foldersOfType: folderType
		      forUID: currentOwner];
      [self _appendFolders: folders toResponse: r];
    }
}

- (id) davCollectionQuery: (WOContext *) queryContext
{
  WOResponse *r;
  NSDictionary *filter;
  id <DOMDocument> document;

  r = [context response];
  [r setStatus: 207];
  [r setContentEncoding: NSUTF8StringEncoding];
  [r setHeader: @"text/xml; charset=\"utf-8\"" forKey: @"content-type"];
  [r setHeader: @"no-cache" forKey: @"pragma"];
  [r setHeader: @"no-cache" forKey: @"cache-control"];
  [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [r appendContentString: @"<D:multistatus xmlns:D=\"DAV:\""
     @" xmlns=\"urn:ietf:params:xml:ns:inverse-dav\">"];

  document = [[context request] contentAsDOMDocument];
  filter = [self _parseCollectionFilters: document];
  [self _appendFoldersOfType: [filter objectForKey: @"resource-type"]
	ofOwnersMatching: [filter objectForKey: @"owner"]
	toResponse: r];

  [r appendContentString:@"</D:multistatus>"];

  return r;
}

- (NSString *) _davFetchUsersMatching: (NSString *) user
{
  LDAPUserManager *um;
  NSMutableString *fetch;
  NSDictionary *currentUser;
  NSString *field, *login;
  NSArray *users;
  int i;

#warning the attributes returned here should match the one requested in the query
  fetch = [NSMutableString string];

  login = [[context activeUser] login];
  um = [LDAPUserManager sharedUserManager];

  // We sort our array - this is pretty useful for the
  // SOGo Integrator extension, among other things.
  users = [[um fetchUsersMatching: user]
	    sortedArrayUsingSelector: @selector (caseInsensitiveDisplayNameCompare:)];
  for (i = 0; i < [users count]; i++)
    {
      currentUser = [users objectAtIndex: i];
      field = [currentUser objectForKey: @"c_uid"];
      if (![field isEqualToString: login])
        {
          [fetch appendFormat: @"<user><id>%@</id>",
                 [field stringByEscapingXMLString]];
          field = [currentUser objectForKey: @"cn"];
          [fetch appendFormat: @"<displayName>%@</displayName>",
                 [field stringByEscapingXMLString]];
          field = [currentUser objectForKey: @"c_email"];
          [fetch appendFormat: @"<email>%@</email>",
                 [field stringByEscapingXMLString]];
          if (LDAPContactInfoAttribute)
            {
              field = [currentUser objectForKey: LDAPContactInfoAttribute];
              if ([field length])
                [fetch appendFormat: @"<info>%@</info>",
                       [field stringByEscapingXMLString]];
            }
          [fetch appendString: @"</user>"];
        }
    }

  return fetch;
}

- (NSString *) _davUsersFromQuery: (id <DOMDocument>) document
{
  id <DOMNode> node, userAttr;
  id <DOMNamedNodeMap> attrs;
  NSString *nodeName, *result, *response, *user;

  node = [[document documentElement] firstChild];
  nodeName = [node nodeName];
  if ([nodeName isEqualToString: @"users"])
    {
      attrs = [node attributes];
      userAttr = [attrs namedItem: @"match-name"];
      user = [userAttr nodeValue];
      if ([user length])
	result = [self _davFetchUsersMatching: user];
      else
	result = nil;
    }
  else
    result = nil;

  if (result)
    {
      if ([result length])
	response = [NSString stringWithFormat: @"<%@>%@</%@>",
			     nodeName, result, nodeName];
      else
	response = @"";
    }
  else
    response = nil;

  return response;
}

- (id) davUserQuery: (WOContext *) queryContext
{
  WOResponse *r;
  id <DOMDocument> document;
  NSString *content;

  r = [queryContext response];
  [r setContentEncoding: NSUTF8StringEncoding];
  [r setHeader: @"text/xml; charset=\"utf-8\"" forKey: @"content-type"];
  [r setHeader: @"no-cache" forKey: @"pragma"];
  [r setHeader: @"no-cache" forKey: @"cache-control"];

  document = [[context request] contentAsDOMDocument];
  content = [self _davUsersFromQuery: document];
  if (content)
    {
      [r setStatus: 207];
      if ([content length])
	{
	  [r appendContentString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
	  [r appendContentString: content];
	}
    }
  else
    [r setStatus: 400];

  return r;
}

- (SOGoAppointmentFolders *) privateCalendars: (NSString *) key
				    inContext: (WOContext *) localContext
{
  SOGoAppointmentFolders *calendars;
  NSString *baseOCSPath;

  calendars = [$(@"SOGoAppointmentFolders") objectWithName: key
		inContainer: self];
  baseOCSPath = [NSString stringWithFormat: @"/Users/%@/Calendar",
			  [self ownerInContext: nil]];
  [calendars setBaseOCSPath: baseOCSPath];

  return calendars;
}

- (SOGoContactFolders *) privateContacts: (NSString *) _key
                               inContext: (WOContext *) _ctx
{
  SOGoContactFolders *contacts;
  NSString *baseOCSPath;

  contacts = [$(@"SOGoContactFolders") objectWithName:_key inContainer: self];
  baseOCSPath = [NSString stringWithFormat: @"/Users/%@/Contacts",
			  [self ownerInContext: nil]];
  [contacts setBaseOCSPath: baseOCSPath];

  return contacts;
}

- (id) mailAccountsFolder: (NSString *) _key
                inContext: (WOContext *) _ctx
{
  return [$(@"SOGoMailAccounts") objectWithName: _key inContainer: self];
}

- (id) freeBusyObject: (NSString *) _key
            inContext: (WOContext *) _ctx
{
  return [$(@"SOGoFreeBusyObject") objectWithName: _key inContainer: self];
}

- (id) calendarProxy: (NSString *) name withWriteAccess: (BOOL) hasWrite
{
  id calendarProxy;

  calendarProxy = [$(@"SOGoCalendarProxy") objectWithName: name
                                              inContainer: self];
  [calendarProxy setWriteAccess: hasWrite];

  return calendarProxy;  
}

- (id) lookupName: (NSString *) _key
        inContext: (WOContext *) _ctx
          acquire: (BOOL) _flag
{
  id obj;
  SOGoUser *currentUser;

  /* first check attributes directly bound to the application */
  obj = [super lookupName: _key inContext: _ctx acquire: NO];
  if (!obj)
    {
      currentUser = [_ctx activeUser];
      if ([currentUser canAccessModule: @"Calendar"])
        {
          if ([_key isEqualToString: @"Calendar"])
	    obj = [self privateCalendars: @"Calendar" inContext: _ctx];
          else if ([_key isEqualToString: @"freebusy.ifb"])
            obj = [self freeBusyObject:_key inContext: _ctx];
          else if ([_key isEqualToString: @"calendar-proxy-write"])
            obj = [self calendarProxy: _key withWriteAccess: YES];
          else if ([_key isEqualToString: @"calendar-proxy-read"])
            obj = [self calendarProxy: _key withWriteAccess: NO];
	}

      if (!obj
          && [_key isEqualToString: @"Mail"]
          && [currentUser canAccessModule: @"Mail"])
        obj = [self mailAccountsFolder: _key inContext: _ctx];

      if (!obj && [_key isEqualToString: @"Contacts"])
        obj = [self privateContacts: _key inContext: _ctx];

      // else if ([_key isEqualToString: @"Preferences"])
      //   obj = [$(@"SOGoPreferencesFolder") objectWithName: _key
      //   	inContainer: self];

      if (!obj)
        obj = [NSException exceptionWithHTTPStatus: 404 /* Not Found */];
    }

  return obj;
}

/* WebDAV */

- (NSArray *) fetchContentObjectNames
{
  static NSArray *cos = nil;
  
  if (!cos)
    cos = [[NSArray alloc] initWithObjects: @"freebusy.ifb", nil];

  return cos;
}

- (NSString *) davDisplayName
{
  return [[LDAPUserManager sharedUserManager]
	   getCNForUID: nameInContainer];
}

- (NSArray *) davPrincipalURL
{
  NSArray *principalURL;
  NSString *selfDAVPath;

  selfDAVPath = [[self davURL] path];
  principalURL = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                          selfDAVPath, nil];

  return [NSArray arrayWithObject: principalURL];
}

@end /* SOGoUserFolder */
