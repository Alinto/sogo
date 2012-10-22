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
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSURL+misc.h>
#import <NGImap4/NGImap4Connection.h>

#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoUser.h>

#import "SOGoMailAccount.h"
#import "SOGoMailManager.h"

#import "SOGoMailBaseObject.h"

@implementation SOGoMailBaseObject

#if 0
static BOOL debugOn = YES;
#endif

- (id) initWithImap4URL: (NSURL *) _url
	    inContainer: (id) _container
{
  NSString *n;
  
  n = [[_url path] lastPathComponent];
  if ((self = [self initWithName: n inContainer:_container]))
    {
      imap4URL = [_url retain];
    }

  return self;
}

- (void) dealloc
{
  [imap4URL release];
  [imap4 release];
  [super dealloc];
}

- (BOOL) isFolderish
{
  return YES;
}

/* hierarchy */

- (SOGoMailAccount *) mailAccountFolder
{
  SOGoMailAccount *folder;

  if ([container respondsToSelector: _cmd])
    folder = [container mailAccountFolder];
  else
    {
      [self warnWithFormat: @"weird container of mailfolder: %@",
	    container];
      folder = nil;
    }
  
  return folder;
}

- (SOGoMailAccounts *) mailAccountsFolder
{
  id o;
  SOGoMailAccounts *folder;
  Class folderClass;

  folder = nil;

  folderClass = NSClassFromString (@"SOGoMailAccounts");
  o = container;
  while (!folder && [o isNotNull])
    if ([o isKindOfClass: folderClass])
      folder = o;
    else
      o = [o container];

  return o;
}

- (BOOL) isInDraftsFolder
{
  return [container isInDraftsFolder];
}

/* IMAP4 */

- (NGImap4ConnectionManager *) mailManager
{
  return [NGImap4ConnectionManager defaultConnectionManager];
}

- (NGImap4Connection *) _createIMAP4Connection
{
  NGImap4ConnectionManager *manager;
  NSString *password;
  NGImap4Connection *newConnection;

  [self imap4URL];
  manager = [self mailManager];
  password = [self imap4PasswordRenewed: NO];
  if (password)
    {
      newConnection = [manager connectionForURL: imap4URL
                                       password: password];
      if (!newConnection)
        {
          [self logWithFormat: @"renewing imap4 password"];
          password = [self imap4PasswordRenewed: YES];
          if (password)
            newConnection = [manager connectionForURL: imap4URL
                                             password: password];
        }
    }
  else
    newConnection = nil;

  if (!newConnection)
    {
      newConnection = (NGImap4Connection *) [NSNull null];
      [self errorWithFormat:@"Could not connect IMAP4"];
    }

  return newConnection;
}

- (NGImap4Connection *) imap4Connection
{
  NSString *cacheKey, *login;
  
  SOGoCache *sogoCache;
  

  if (!imap4)
    {
      sogoCache = [SOGoCache sharedCache];
      // The cacheKey *MUST* be prefixed by the username here as
      // the cache is shared across OpenChange users and not necessarily
      // flushed between requests. This could lead us to using the wrong
      // IMAP connection.
      //
      // We also have a HACK in case self's context doesn't exist, we
      // use the container's one.
      //
      login = [[[self context] activeUser] login];
      
      if (!login)
	login = [[[[self container] context] activeUser] login];

      cacheKey = [NSString stringWithFormat: @"%@+%@",
			   login,
			   [[self mailAccountFolder] nameInContainer]];
      imap4 = [sogoCache imap4ConnectionForKey: cacheKey];
      if (!imap4)
        {
          imap4 = [self _createIMAP4Connection];
          [sogoCache registerIMAP4Connection: imap4
                                      forKey: cacheKey];
        }
      [imap4 retain];
    }

  return [imap4 isKindOfClass: [NSNull class]] ? nil : imap4;
}

- (NSString *) relativeImap4Name
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSURL *) baseImap4URL
{
  NSURL *url;

  if ([container respondsToSelector: @selector(imap4URL)])
    url = [container imap4URL];
  else
    {
      [self warnWithFormat:@"container does not implement -imap4URL!"];
      url = nil;
    }
  
  return url;
}

- (NSMutableString *) imap4URLString
{
  NSMutableString *urlString;
  NSString *imap4Name;

  urlString = [container imap4URLString];
  imap4Name = [[self relativeImap4Name] stringByEscapingURL];
  [urlString appendFormat: @"%@", imap4Name];

  return urlString;
}

- (NSURL *) imap4URL
{
  SOGoMailAccount *account;
  NSString *urlString;

  /* this could probably be handled better from NSURL but it's buggy in
     GNUstep */
  if (!imap4URL)
    {
      account = [self mailAccountFolder];
      if ([[account encryption] isEqualToString: @"tls"])
        urlString = [NSString stringWithFormat: @"%@?tls=YES",
                              [self imap4URLString]];
      else
	urlString = [self imap4URLString];
      imap4URL = [[NSURL alloc] initWithString: urlString];
    }

  return imap4URL;
}

- (NSString *) imap4PasswordRenewed: (BOOL) renewed
{
  return [[self mailAccountFolder] imap4PasswordRenewed: renewed];
}

- (NSMutableString *) traversalFromMailAccount
{
  NSMutableString *currentTraversal;

  currentTraversal = [container traversalFromMailAccount];
  if ([container isKindOfClass: [SOGoMailAccount class]])
    [currentTraversal appendString: [self relativeImap4Name]];
  else
    [currentTraversal appendFormat: @"/%@", [self relativeImap4Name]];

  return currentTraversal;
}

- (void)flushMailCaches {
  [[self mailManager] flushCachesForURL:[self imap4URL]];
}

/* IMAP4 names */

#warning we could improve this by simply testing if the reference is the filename of an attachment or if the body part mentionned actually exists in the list of body parts. Another way is to use a prefix such as "attachment-*" to declare attachments.
- (BOOL) isBodyPartKey: (NSString *) key
{
  NSString *trimmedKey;

  trimmedKey = [key stringByTrimmingCharactersInSet:
		      [NSCharacterSet decimalDigitCharacterSet]];

  return (![trimmedKey length]);
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return nil;
}

- (int) IMAP4IDFromAppendResult: (NSDictionary *) result
{
  NSDictionary *results;
  NSString *flag, *newIdString;

  results = [[result objectForKey: @"RawResponse"]
                     objectForKey: @"ResponseResult"];
  flag = [results objectForKey: @"flag"];
  newIdString = [[flag componentsSeparatedByString: @" "] objectAtIndex: 2];

  return [newIdString intValue];
}

@end /* SOGoMailBaseObject */
