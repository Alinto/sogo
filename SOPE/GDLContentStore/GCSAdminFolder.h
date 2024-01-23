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

#ifndef GCSALARMSFOLDER_H
#define GCSALARMSFOLDER_H


@class NSCalendarDate;
@class NSException;
@class NSNumber;
@class NSString;

@class GCSFolderManager;

@interface GCSAdminFolder : NSObject
{
  GCSFolderManager *folderManager;
}

+ (id)adminFolderWithFolderManager:(GCSFolderManager *)newFolderManager;

- (void) setFolderManager: (GCSFolderManager *) newFolderManager;

/* operations */

- (NSString *)getMotd;

- (void) createFolderIfNotExists;
- (BOOL) canConnectStore;

- (NSException *)writeMotd:(NSString *)motd;
- (NSException *)deleteMotd;

@end

#endif /* GCSALARMSFOLDER_H */
