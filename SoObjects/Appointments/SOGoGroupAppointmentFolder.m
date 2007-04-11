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

#import <SOGo/SOGoGroupFolder.h>

#include "SOGoGroupAppointmentFolder.h"
#include "common.h"

@implementation SOGoGroupAppointmentFolder

+ (int)version {
  return [super version] + 0 /* v1 */;
}
+ (void)initialize {
  NSAssert2([super version] == 1,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (void)dealloc {
  [self->uidToFolder release];
  [super dealloc];
}

/* looking up shared objects */

- (SOGoGroupsFolder *)lookupGroupsFolder {
  return [[self container] lookupGroupsFolder];
}

/* selection */

- (NSArray *)calendarUIDs {
  return [[self container] valueForKey:@"uids"];
}

/* folders */

- (void)resetFolderCaches {
  [self->uidToFolder release]; self->uidToFolder = nil;
}

- (SOGoAppointmentFolder *)folderForUID:(NSString *)_uid {
  if (self->uidToFolder == nil) {
    // TODO: can we trigger a fetch?
    [self errorWithFormat:
            @"called -folderForUID method before fetchCoreInfos .."];
    return nil;
  }
  
  return [self->uidToFolder objectForKey:_uid];
}

/* merging */

- (BOOL)doesRecord:(NSDictionary *)_rec conflictWith:(NSDictionary *)_other {
  if (_rec == _other) 
    return NO;
  if ([_rec isEqual:_other])
    return NO;
  
  return YES;
}

- (NSDictionary *)_registerConflictingRecord:(NSDictionary *)_other
  inRecord:(NSDictionary *)_record
{
  NSMutableArray *conflicts;
  
  if (_record == nil) return _other;
  if (_other  == nil) return _record;
  
  if ((conflicts = [_record objectForKey:@"conflicts"]) == nil) {
    NSMutableDictionary *md;
    
    md = [[_record mutableCopy] autorelease];
    conflicts = [NSMutableArray arrayWithCapacity:4];
    [md setObject:conflicts forKey:@"conflicts"];
    _record = md;
  }
  [conflicts addObject:_other];
  return _record;
}

/* functionality */

- (SOGoAppointmentFolder *)calendarFolderForMemberFolder:(id)_folder {
  SOGoAppointmentFolder *aptFolder;
  
  if (![_folder isNotNull])
    return nil;
  
  aptFolder = [_folder lookupName:@"Calendar" inContext:nil acquire:NO];
  if (![aptFolder isNotNull])
    return nil;
  
  if (![aptFolder respondsToSelector:@selector(fetchCoreInfosFrom:to:component:)]) {
    [self errorWithFormat:@"folder does not implemented required API: %@",
	    _folder];
    return nil;
  }
  return aptFolder;
}

/* overridden */
- (NSArray *) fetchFields: (NSArray *) _fields
                     from: (NSCalendarDate *) _startDate
                       to: (NSCalendarDate *) _endDate
                component: (id) _component
{
  NSArray             *folders;
  NSMutableArray      *result;
  NSMutableDictionary *uidToRecord;
  unsigned            i, count;
  SoSecurityManager *securityManager;

  securityManager = [SoSecurityManager sharedSecurityManager];

  folders = [[self container] memberFolders];
  [self resetFolderCaches];
  
  if ((count = [folders count]) == 0)
    return [NSArray array];
  
  if (self->uidToFolder == nil)
    self->uidToFolder = [[NSMutableDictionary alloc] initWithCapacity:7*count];
  else
    [self->uidToFolder removeAllObjects];
  
  uidToRecord = [NSMutableDictionary dictionaryWithCapacity:(7 * count)];
  result      = [NSMutableArray arrayWithCapacity:(7 * count)];
  for (i = 0; i < count; i++) {
    SOGoAppointmentFolder *aptFolder;
    id                    results;
    NSDictionary          *record;

    aptFolder = [self calendarFolderForMemberFolder:
			[folders objectAtIndex:i]];
    if (![aptFolder isNotNull]) {
      [self debugWithFormat:@"did not find a Calendar folder in folder: %@",
	      [folders objectAtIndex:i]];
      continue;
    }

    if ([securityManager validatePermission: SoPerm_AccessContentsInformation
                         onObject: aptFolder
                         inContext: context]) {
      [self debugWithFormat:@"no permission to read the content of calendar: %@",
	    [folders objectAtIndex:i]];
      continue;
    }

    results = [aptFolder fetchFields: _fields
                         from: _startDate
                         to: _endDate
                         component: _component];
    if (![results isNotNull]) continue;
    
    results = [results objectEnumerator];
    while ((record = [results nextObject])) {
      NSString     *uid;
      NSDictionary *existingRecord;
      
      uid = [record objectForKey:@"uid"];
      if (![uid isNotNull]) {
        [self warnWithFormat:@"record without uid: %@", result];
        [result addObject:record];
        continue;
      }
      
      if ((existingRecord = [uidToRecord objectForKey:uid]) == nil) {
        /* record not yet in result set */
        [uidToRecord setObject:record forKey:uid];
        [result addObject:record];
        
        [self->uidToFolder setObject:aptFolder forKey:uid];
      }
      else if ([self doesRecord:existingRecord conflictWith:record]) {
        /* record already registered and it conflicts (diff values) */
        NSDictionary *newRecord;
        int idx;
        
        newRecord = [self _registerConflictingRecord:record 
                          inRecord:existingRecord];
        [uidToRecord setObject:newRecord forKey:uid];
        
        if ((idx = [result indexOfObject:existingRecord]) != NSNotFound)
          [result replaceObjectAtIndex:idx withObject:newRecord];
      }
      else {
        /* record already registered, but values in sync, nothing to do */
      }
    }
  }
  return result;
}


/* URL generation */

- (NSString *)baseURLForAptWithUID:(NSString *)_uid inContext:(id)_ctx {
  /* Note: fetchCore must have been called before this works */
  SOGoAppointmentFolder *folder;
  
  if ([_uid length] == 0) {
    [self errorWithFormat:@"got invalid UID."];
    return nil;
  }
  
  if ((folder = [self folderForUID:_uid]) == nil) {
    [self errorWithFormat:@"did not find a folder containing UID: '%@'",
	    _uid];
    return nil;
  }
  if (![folder respondsToSelector:_cmd]) {
    [self errorWithFormat:@"found folder cannot construct UID URLs: %@",
	    folder];
    return nil;
  }
  
  [self debugWithFormat:@"found ID %@ in folder: %@", _uid, folder];
  
  return [folder baseURLForAptWithUID:_uid inContext:_ctx];
}

@end /* SOGoGroupAppointmentFolder */
