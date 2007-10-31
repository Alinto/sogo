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

#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSURL+misc.h>

#import <SoObjects/SOGo/SOGoAuthenticator.h>

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
  [super dealloc];
}

/* hierarchy */

- (SOGoMailAccount *) mailAccountFolder
{
  SOGoMailAccount *folder;

  if ([container respondsToSelector:_cmd])
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

- (NGImap4Connection *) imap4Connection
{
  if (!imap4)
    {
      imap4 = [[self mailManager] connectionForURL: [self imap4URL] 
				  password: [self imap4Password]];
      if (imap4)
	[imap4 retain];
      else
	[self errorWithFormat:@"Could not connect IMAP4."];
    }

  return imap4;
}

- (NSString *) relativeImap4Name
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSURL *) baseImap4URL
{
  NSURL *url;

  if ([container respondsToSelector:@selector(imap4URL)])
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
  /* this could probably be handled better from NSURL but it's buggy in
     GNUstep */
  if (!imap4URL)
    imap4URL = [[NSURL alloc] initWithString: [self imap4URLString]];

  return imap4URL;
}

- (NSString *) imap4Login
{
  if (![container respondsToSelector:_cmd])
    return nil;
  
  return [container imap4Login];
}

- (NSString *) imap4Password
{
  /*
    Extract password from basic authentication.
    
    TODO: we might want to
    a) move the primary code to SOGoMailAccount
    b) cache the password
  */

  return [[self authenticatorInContext: context] passwordInContext: context];
}

- (NSMutableString *) traversalFromMailAccount
{
  NSMutableString *currentTraversal;

  currentTraversal = [container traversalFromMailAccount];
  [currentTraversal appendFormat: @"/%@", [self relativeImap4Name]];

  return currentTraversal;
}

- (void)flushMailCaches {
  [[self mailManager] flushCachesForURL:[self imap4URL]];
}

/* IMAP4 names */

- (BOOL)isBodyPartKey:(NSString *)_key inContext:(id)_ctx {
  /*
    Every key starting with a digit is consider an IMAP4 mime part key, used in
    SOGoMailObject and SOGoMailBodyPart.
  */
  if ([_key length] == 0)
    return NO;
  
  if (isdigit([_key characterAtIndex:0]))
    return YES;
  
  return NO;
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return nil;
}

@end /* SOGoMailBaseObject */
