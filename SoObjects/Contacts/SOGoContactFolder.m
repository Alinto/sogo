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

#include "SOGoContactFolder.h"
#include <SOGo/SOGoCustomGroupFolder.h>
#include <SOGo/AgenorUserManager.h>
#include <GDLContentStore/GCSFolder.h>
#include <NGiCal/NGiCal.h>
#include "common.h"
#include <unistd.h>
#include <stdlib.h>

@implementation SOGoContactFolder

+ (id) contactFolderWithSource: (SOGoContactSource *) source
                   inContainer: (SOGoObject *) container
                       andName: (NSString *) name
{
  SOGoContactFolder *folder;

  folder = [[self alloc] initWithSource: source
                         inContainer: container
                         andName: name];
  [folder autorelease];

  return folder;
}

- (id) initWithSource: (SOGoContactSource *) source
          inContainer: (SOGoObject *) newContainer
              andName: (NSString *) name
{
  if ((self = [self initWithName: name inContainer: newContainer]))
    [self setContactSource: source andName: name];

  return self;
}

- (void) setContactSource: (SOGoContactSource *) source
                  andName: name
{
}

/* name lookup */

- (BOOL)isValidContactName:(NSString *)_key {
  if ([_key length] == 0)
    return NO;
  
  return YES;
}

- (id) contactWithName: (NSString *) _key
             inContext: (id)_ctx
{
  static Class ctClass = Nil;
  id ct;
  
  if (ctClass == Nil)
    ctClass = NSClassFromString(@"SOGoContactObject");
  if (ctClass == Nil) {
    [self errorWithFormat:@"missing SOGoContactObject class!"];
    return nil;
  }
  
  ct = [[ctClass alloc] initWithName:_key inContainer:self];
  return [ct autorelease];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  id obj;
  
  /* first check attributes directly bound to the application */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]))
    return obj;
  
  if ([self isValidContactName:_key]) {
#if 0
    if ([[self ocsFolder] versionOfContentWithName:_key])
#endif
      return [self contactWithName:_key inContext:_ctx];
  }

  /* return 404 to stop acquisition */
  return [NSException exceptionWithHTTPStatus:404 /* Not Found */];
}

/* fetching */

- (NSArray *)fixupRecords:(NSArray *)_records {
  return _records;
}

- (NSArray *)fetchCoreInfos {
  NSArray     *fields, *records;

  fields = [NSArray arrayWithObjects:
		      @"c_name", @"cn",
		      @"sn", @"givenname", @"l", 
		      @"mail", @"telephonenumber",
		    nil];
  records = [[self ocsFolder] fetchFields:fields matchingQualifier:nil];
  if (records == nil) {
    [self errorWithFormat:@"(%s): fetch failed!", __PRETTY_FUNCTION__];
    return nil;
  }
  records = [self fixupRecords:records];
  //[self debugWithFormat:@"fetched %i records.", [records count]];
  return records;
}

/* GET */

- (id)GETAction:(id)_ctx {
  // TODO: I guess this should really be done by SOPE (redirect to
  //       default method)
  WOResponse *r;
  NSString *uri;

  uri = [[_ctx request] uri];
  if (![uri hasSuffix:@"/"]) uri = [uri stringByAppendingString:@"/"];
  uri = [uri stringByAppendingString:@"view"];
  
  r = [_ctx response];
  [r setStatus:302 /* moved */];
  [r setHeader:uri forKey:@"location"];
  return r;
}

/* folder type */

- (NSString *)outlookFolderClass {
  return @"IPF.Contact";
}

@end /* SOGoContactFolder */
