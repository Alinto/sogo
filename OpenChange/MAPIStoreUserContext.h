/* MAPIStoreUserContext.h - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2012 Inverse inc
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

#ifndef MAPISTOREUSERCONTEXT_H
#define MAPISTOREUSERCONTEXT_H

#import <Foundation/NSObject.h>

@class NSMutableDictionary;
@class NSString;
@class NSTimeZone;
@class NSURL;

@class WOContext;

@class SOGoAppointmentFolders;
@class SOGoContactFolders;
@class SOGoMailAccount;
@class SOGoUser;
@class SOGoUserFolder;

@class MAPIStoreAuthenticator;
@class MAPIStoreMapping;

@interface MAPIStoreUserContext : NSObject
{
  NSString *username;
  SOGoUser *sogoUser;
  NSTimeZone *timeZone;

  SOGoUserFolder *userFolder;
  NSMutableArray *containersBag;
  NSMutableDictionary *rootFolders;

  MAPIStoreMapping *mapping;

  BOOL userDbTableExists;
  NSURL *folderTableURL;

  WOContext *woContext;
  MAPIStoreAuthenticator *authenticator;

  BOOL inboxHasNoInferiors;
}

+ (id) userContextWithUsername: (NSString *) username
                andTDBIndexing: (struct tdb_wrap *) indexingTdb;

- (id) initWithUsername: (NSString *) newUsername
         andTDBIndexing: (struct tdb_wrap *) indexingTdb;

- (NSString *) username;
- (SOGoUser *) sogoUser;

- (NSTimeZone *) timeZone;

- (SOGoUserFolder *) userFolder;

- (NSDictionary *) rootFolders;

- (BOOL) inboxHasNoInferiors;

- (NSURL *) folderTableURL;
- (MAPIStoreMapping *) mapping;

- (void) ensureFolderTableExists;

/* SOGo hacky magic */
- (void) activateWithUser: (SOGoUser *) activeUser;
- (MAPIStoreAuthenticator *) authenticator;
- (WOContext *) woContext;

@end

#endif /* MAPISTOREUSERCONTEXT_H */
