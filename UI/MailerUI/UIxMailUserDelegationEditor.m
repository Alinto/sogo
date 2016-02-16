/* UIxMailUserDelegationEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2015 Inverse inc.
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

#import <Foundation/NSArray.h>


#import <SOGoUI/UIxComponent.h>

@interface UIxMailUserDelegationEditor : UIxComponent
// {
//   NSArray *delegates;
//   NSString *currentDelegate;
// }

// - (NSArray *) delegates;
// - (void) setCurrentDelegate: (NSString *) newCurrentDelegate;
// - (NSString *) currentDelegate;

@end

@implementation UIxMailUserDelegationEditor

// - (id) init
// {
//   if ((self = [super init]))
//     {
//       delegates = nil;
//       currentDelegate = nil;
//     }

//   return self;
// }

// - (void) dealloc
// {
//   [delegates release];
//   [currentDelegate release];
//   [super dealloc];
// }

// - (NSArray *) delegates
// {
//   if (!delegates)
//     {
//       delegates = [[self clientObject] delegates];
//       [delegates retain];
//     }

//   return delegates;
// }

// - (void) setCurrentDelegate: (NSString *) newCurrentDelegate
// {
//   ASSIGN (currentDelegate, newCurrentDelegate);
// }

// - (NSString *) currentDelegate
// {
//   return currentDelegate;
// }

// - (NSString *) currentDelegateDisplayName
// {
//   SOGoUserManager *um;
//   NSString *s;

//   um = [SOGoUserManager sharedUserManager];
//   s = ([currentDelegate hasPrefix: @"@"]
//        ? [currentDelegate substringFromIndex: 1]
//        : currentDelegate);

//   return [um getFullEmailForUID: s];
// }

// - (id) defaultAction
// {
//   id response;
//   SOGoMailAccount *co;

//   co = [self clientObject];
//   if ([[co nameInContainer] isEqualToString: @"0"])
//     response = self;
//   else
//     response = [self responseWithStatus: 403
//                               andString: @"The list of account delegates cannot be modified on secondary accounts."];

//   return response;
// }

@end
