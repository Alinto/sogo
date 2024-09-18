/* GCSAdminFolder.h - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2023 Alinto
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

#ifndef GCSOPENIDFOLDER_H
#define GCSOPENIDOLDER_H


@class NSCalendarDate;
@class NSException;
@class NSNumber;
@class NSString;

@class GCSFolderManager;

@interface GCSOpenIdFolder : NSObject
{
  GCSFolderManager *folderManager;
}

+ (id)openIdFolderWithFolderManager:(GCSFolderManager *)newFolderManager;

- (void) setFolderManager: (GCSFolderManager *) newFolderManager;

/* operations */

- (void) createFolderIfNotExists;
- (BOOL) canConnectStore;

- (NSString *) getRefreshToken: (NSString *) _user_session useOldSession: (BOOL) use_old_session;
- (NSString *) getNewToken: (NSString *) _old_session;
- (NSException *) writeOpenIdSession: (NSString *) _user_session
                  withOldSession: (NSString *) _old_session
                  withRefreshToken: (NSString *) _refresh_token
                  withExpire: (NSNumber *) _expire
                  withRefreshExpire: (NSNumber *) _refresh_expire;
- (NSException *) deleteOpenIdSessionFor: (NSString *) _user_session;

@end

#endif /* GCSALARMSFOLDER_H */
