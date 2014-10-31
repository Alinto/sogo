/* UIxAclEditor.h - this file is part of SOGo
 *
 * Copyright (C) 2006-2014 Inverse inc.
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

#ifndef UIXACLEDITOR_H
#define UIXACLEDITOR_H

#import <SOGoUI/UIxComponent.h>

@interface UIxAclEditor : UIxComponent
{
  BOOL prepared;
  BOOL publishInFreeBusy;
  NSArray *aclUsers;
  NSArray *savedUIDs;
  NSMutableDictionary *users;
  NSString *currentUser;
  NSString *defaultUserID;
}

- (NSArray *) aclsForObject;

- (void) setCurrentUser: (NSString *) newCurrentUser;
- (NSString *) currentUser;
- (NSString *) currentUserClass;
- (NSDictionary *) currentUserInfos;
- (NSString *) currentUserDisplayName;
- (BOOL) currentUserIsSubscribed;
- (BOOL) isPublicAccessEnabled;

@end

#endif /* UIXACLEDITOR_H */
