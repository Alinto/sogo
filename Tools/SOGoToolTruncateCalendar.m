/* SOGoToolTruncateCalendar.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2016 Inverse inc.
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


#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <EOControl/EOQualifier.h>

#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>

#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>

#import "SOGoTool.h"

@interface SOGoToolTruncateCalendar : SOGoTool
@end

@implementation SOGoToolTruncateCalendar

+ (NSString *) command
{
  return @"truncate-calendar";
}

+ (NSString *) description
{
  return @"remove old calendar entries from the specified user calendar";
}

- (void) removeRecord: (NSString *) recordName
	    fromTable: (NSString *) tableName
	andQuickTable: (NSString *) quickTableName
	 usingChannel: (EOAdaptorChannel *) channel
{
  NSString *delSql;
  NSCalendarDate *now;

  /* We remove the records without regards to c_deleted because we really want
     to recover table space. */

  now = [NSCalendarDate date];
  delSql = [NSString stringWithFormat: @"UPDATE %@"
                     @" SET c_deleted = 1, c_lastmodified = %lu,"
                     @" c_content = ''"
		     @" WHERE c_name = '%@'",
		     tableName,
                     (NSUInteger) [now timeIntervalSince1970],
                     recordName];
  [channel evaluateExpressionX: delSql];
  delSql = [NSString stringWithFormat: @"DELETE FROM %@"
		     @" WHERE c_name = '%@'",
		     quickTableName, recordName];
  [channel evaluateExpressionX: delSql];
}

- (void) removeRecords: (NSArray *) recordNames
	    fromFolder: (GCSFolder *) folder
{
  NSString *tableName, *quickTableName, *currentRecordName;
  NSDictionary *currentRecord;
  EOAdaptorChannel *channel;
  EOAdaptorContext *context;
  NSEnumerator *recordsEnum;

  fprintf (stderr,
#if GS_64BIT_OLD
           "Removing %d records...\n",
#else
           "Removing %ld records...\n",
#endif
           [recordNames count]);

  channel = [folder acquireStoreChannel];
  context = [channel adaptorContext];
  [context beginTransaction];

  tableName = [folder storeTableName];
  quickTableName = [folder quickTableName];

  recordsEnum = [recordNames objectEnumerator];
  while ((currentRecord = [recordsEnum nextObject]))
    {
      currentRecordName = [currentRecord objectForKey: @"c_name"];
      [self removeRecord: currentRecordName
	       fromTable: tableName andQuickTable: quickTableName
	    usingChannel: channel];
    }

  [context commitTransaction];
  [folder releaseChannel: channel];
}

- (BOOL) truncateEntriesFromFolder: (GCSFolder *) folder
			 usingDate: (NSCalendarDate *) date
{
  NSMutableArray *records;
  EOQualifier *qualifier;
  NSArray *fields;
  NSString *qs;
  BOOL rc;

  records = [NSMutableArray array];
  fields = [NSArray arrayWithObjects: @"c_name", nil];

  // We fetch non-repetitive events
  qs = [NSString stringWithFormat: @"c_enddate <= %d AND c_iscycle == 0 AND c_component == 'vevent'", (int)[date timeIntervalSince1970]];
  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
  [records addObjectsFromArray: [folder fetchFields: fields matchingQualifier: qualifier]];

  // We fetch repetitive events with a cycle end date
  qs = [NSString stringWithFormat: @"c_cycleenddate <= %d AND c_iscycle == 1 AND c_component == 'vevent'", (int)[date timeIntervalSince1970]];
  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
  [records addObjectsFromArray: [folder fetchFields: fields matchingQualifier: qualifier]];

  if (records)
    {
      rc = YES;
      
      if ([records count])
        {
          [self removeRecords: records  fromFolder: folder];
          fprintf (stderr,
#if GS_64BIT_OLD
                   "Removed %d records.\n",
#else
                   "Removed %ld records.\n",
#endif
                   [records count]);
        }
      else
        fprintf (stderr,
                 "No record to remove. All records kept.\n");
    }
  else
    {
      fprintf (stderr, "Unable to fetch required fields from folder.\n");
      rc = NO;
    }

  return rc;
}

- (BOOL) processFolder: (NSString *) folderId
		ofUser: (NSString *) username
		  date: (NSCalendarDate *) date
	       withFoM: (GCSFolderManager *) fom
{
  NSString *folderPath;
  GCSFolder *folder;
  BOOL rc;

  folderPath = [NSString stringWithFormat: @"/Users/%@/Calendar/%@",
			 username, folderId];
  folder = [fom folderAtPath: folderPath];
  if (folder)
    rc = [self truncateEntriesFromFolder: folder  usingDate: date];
  else
    {
      fprintf (stderr, "Folder '%s' of user '%s' not found.\n",
	       [folderId UTF8String], [username UTF8String]);
      rc = NO;
    }

  return rc;
}

- (BOOL) runWithFolder: (NSString *) folder
	       andUser: (NSString *) username
		  date: (NSString *) date
{
  GCSFolderManager *fom;
  NSCalendarDate *d;
  NSString *s;
  BOOL rc;

  // We force parsing in the GMT timezone. If we don't do that, the date will be parsed
  // in the default timezone.
  s = [NSString stringWithFormat: @"%@ GMT", date];  
  d = [NSCalendarDate dateWithString: s  calendarFormat: @"%Y-%m-%dT%H:%M:%S %Z"];
  fom = [GCSFolderManager defaultFolderManager];

  if (d && fom)
    rc = [self processFolder: folder
		      ofUser: username
			date: d
		     withFoM: fom];
  else
    rc = NO;

  return rc;
}

- (void) usage
{
  fprintf (stderr, "Usage: truncate-calendar USER FOLDER DATE\n\n"
	   "         USER       the owner of the contact folder\n"
	   "         FOLDER     the id of the folder to clean up\n"
	   "         DATE       UTC datetime - non-recurring events older than this date will be removed (ex: \"2016-06-27T17:38:56\")\n\n");
}

- (BOOL) run
{
  BOOL rc;

  if ([arguments count] == 3)
    rc = [self runWithFolder: [arguments objectAtIndex: 1]
                     andUser: [arguments objectAtIndex: 0]
			date: [arguments objectAtIndex: 2]];
  else
    {
      [self usage];
      rc = NO;
    }

  return rc;
}

@end
