/* EOQualifier+MAPIFS.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>

#import "SOGoMAPIFSMessage.h"

#import "EOQualifier+MAPIFS.h"

@implementation EOQualifier (MAPIStoreRestrictions)

- (BOOL) _evaluateMAPIFSMessageProperties: (NSDictionary *) properties
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (BOOL) evaluateMAPIFSMessage: (SOGoMAPIFSMessage *) message
{
  NSDictionary *properties;

  [self logWithFormat: @"evaluating message '%@'", message];

  properties = [message properties];

  return [self _evaluateMAPIFSMessageProperties: properties];
}

@end

@implementation EOAndQualifier (MAPIStoreRestrictionsPrivate)

- (BOOL) _evaluateMAPIFSMessageProperties: (NSDictionary *) properties
{
  NSUInteger i;
  BOOL rc;

  rc = YES;

  for (i = 0; rc && i < count; i++)
    rc = [[qualifiers objectAtIndex: i]
	   _evaluateMAPIFSMessageProperties: properties];
 
  return rc;
}

@end

@implementation EOOrQualifier (MAPIStoreRestrictionsPrivate)

- (BOOL) _evaluateMAPIFSMessageProperties: (NSDictionary *) properties
{
  NSUInteger i;
  BOOL rc;

  rc = NO;

  for (i = 0; !rc && i < count; i++)
    rc = [[qualifiers objectAtIndex: i]
	   _evaluateMAPIFSMessageProperties: properties];
 
  return rc;
}

@end

@implementation EONotQualifier (MAPIStoreRestrictionsPrivate)

- (BOOL) _evaluateMAPIFSMessageProperties: (NSDictionary *) properties
{
  return ![qualifier _evaluateMAPIFSMessageProperties: properties];
}

@end

@implementation EOKeyValueQualifier (MAPIStoreRestrictionsPrivate)

- (BOOL) _evaluateMAPIFSMessageProperties: (NSDictionary *) properties
{
  NSNumber *propTag;
  id propValue;

  propTag = [NSNumber numberWithInt: [key intValue]];
  propValue = [properties objectForKey: propTag];

  return [propValue performSelector: operator withObject: value] != nil;
}

@end
