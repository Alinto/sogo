/* GCSSpecialQueries.h - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2010 Inverse inc.
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

#ifndef GCSSPECIALQUERIES_H
#define GCSSPECIALQUERIES_H

#import <Foundation/NSObject.h>

#import <GDLAccess/EOAdaptorChannel.h>

@class NSString;

@interface GCSSpecialQueries : NSObject

- (NSString *) createEMailAlarmsFolderWithName: (NSString *) tableName;
- (NSDictionary *) emailAlarmsAttributeTypes;

- (NSString *) createFolderTableWithName: (NSString *) tableName;
- (NSString *) createFolderACLTableWithName: (NSString *) tableName;

- (NSString *) createSessionsFolderWithName: (NSString *) tableName;
- (NSDictionary *) sessionsAttributeTypes;

@end

@interface EOAdaptorChannel (GCSSpecialQueries)

- (GCSSpecialQueries *) specialQueries;

@end

/* interfaces exposed so that categories can be created from them */
@interface GCSPostgreSQLSpecialQueries : GCSSpecialQueries
@end

@interface GCSMySQLSpecialQueries : GCSSpecialQueries
@end

@interface GCSOracleSpecialQueries : GCSSpecialQueries
@end


#endif /* GCSSPECIALQUERIES_H */
