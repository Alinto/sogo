/* SOGoMAPIDBMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc.
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
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSException.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>

#import "SOGoMAPIDBFolder.h"

#import "SOGoMAPIDBMessage.h"

@implementation SOGoMAPIDBMessage

- (Class) mapistoreMessageClass
{
  // NSArray *dirMembers;
  NSString *className;

  [NSException raise: @"whereisthisusedexception"
              format: @"this exception should be triggered only for tracing"];
  // /* FIXME: this method is a bit dirty */
  // dirMembers = [[container directory] componentsSeparatedByString: @"/"];
  // if ([dirMembers containsObject: @"fai"]) /* should not occur as FAI message
  //                                             are instantiated directly in
  //                                             MAPIStoreFolder */
  //   className = @"MAPIStoreFAIMessage";
  // else if ([dirMembers containsObject: @"notes"])
  //   className = @"MAPIStoreNotesMessage";
  // else
  //   className = @"MAPIStoreDBMessage";

  className = @"nimportequoi";
  return NSClassFromString (className);
}

@end
