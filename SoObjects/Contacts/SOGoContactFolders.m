/* SOGoContactFolders.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/SoUser.h>

#import "common.h"

#import "SOGoContactFolder.h"
#import "SOGoContactSource.h"
#import "SOGoPersonalAB.h"

#import "SOGoContactFolders.h"

@implementation SOGoContactFolders

- (id) init
{
  if ((self = [super init]))
    {
      contactSources = nil;
      OCSPath = nil;
    }

  return self;
}

- (void) dealloc
{
  if (contactSources)
    [contactSources release];
  if (OCSPath)
    [OCSPath release];
  [super dealloc];
}

- (void) appendPersonalSourcesInContext: (WOContext *) context;
{
  SOGoPersonalAB *ab;

  ab = [SOGoPersonalAB personalABForUser: [[context activeUser] login]];
  [contactSources setObject: ab forKey: @"personal"];
}

- (void) appendSystemSourcesInContext: (WOContext *) context;
{
}

- (void) initContactSourcesInContext: (WOContext *) context;
{
  if (!contactSources)
    {
      contactSources = [NSMutableDictionary new];
      [self appendPersonalSourcesInContext: context];
      [self appendSystemSourcesInContext: context];
    }
}

- (id) lookupName: (NSString *) name
        inContext: (WOContext *) context
          acquire: (BOOL) acquire
{
  id obj;
  SOGoContactSource *source;

  /* first check attributes directly bound to the application */
  obj = [super lookupName: name inContext: context acquire: NO];
  if (!obj)
    {
      if (!contactSources)
        [self initContactSourcesInContext: context];

      source = [contactSources objectForKey: name];
      if (source)
        {
          obj = [SOGoContactFolder contactFolderWithSource: source
                                   inContainer: self
                                   andName: name];
          [obj setOCSPath: [NSString stringWithFormat: @"%@/%@",
                                     OCSPath, name]];
        }
      else
        obj = [NSException exceptionWithHTTPStatus: 200];
    }

  return obj;
}

- (NSArray *) toManyRelationshipKeys
{
  WOContext *context;

  if (!contactSources)
    {
      context = [[WOApplication application] context];
      [self initContactSourcesInContext: context];
    }

  return [contactSources allKeys];
}

- (BOOL) davIsCollection
{
  return YES;
}

- (void) setBaseOCSPath: (NSString *) newOCSPath
{
  if (OCSPath)
    [OCSPath release];
  OCSPath = newOCSPath;
  if (OCSPath)
    [OCSPath retain];
}

/* web interface */
- (NSString *) defaultSourceName
{
  return @"personal";
}

@end
