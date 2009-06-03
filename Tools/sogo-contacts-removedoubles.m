/* sogo-ab-removedoubles.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
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

/* TODO: NSUserDefaults bootstrapping for using different backends */

#include <stdio.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <NGCards/NGVList.h>

#import <EOControl/EOQualifier.h>

#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>

typedef void (*NSUserDefaultsInitFunction) ();

@interface NGVList (RemoveDoubles)

- (NSArray *) cardNames;

@end

@implementation NGVList (RemoveDoubles)

- (NSArray *) cardNames
{
  NSEnumerator *cardReferences;
  NSMutableArray *cardNames;
  CardElement *currentReference;

  cardNames = [NSMutableArray array];

  cardReferences = [[self cardReferences] objectEnumerator];

  while ((currentReference = [cardReferences nextObject]))
    [cardNames addObject: [currentReference value: 0]];

  return cardNames;
}

@end

@interface SOGoDoublesRemover : NSObject
@end

@implementation SOGoDoublesRemover

+ (void) initialize
{
  NSUserDefaults *ud;

  ud = [NSUserDefaults standardUserDefaults];
  [ud addSuiteNamed: @"sogod"];
}

- (void) feedDoubleEmails: (NSMutableDictionary *) doubleEmails
	       withRecord: (NSDictionary *) record
{
  NSString *recordEmail;
  NSMutableArray *recordList;

  /* we want to match c_mail case-insensitively */
  recordEmail = [[record objectForKey: @"c_mail"] uppercaseString];
  if ([recordEmail length])
    {
      recordList = [doubleEmails objectForKey: recordEmail];
      if (!recordList)
	{
	  recordList = [NSMutableArray arrayWithCapacity: 5];
	  [doubleEmails setObject: recordList forKey: recordEmail];
	}
      [recordList addObject: record];
    }
}

- (void) cleanupSingleRecords: (NSMutableDictionary *) doubleEmails
{
  NSEnumerator *keys;
  NSString *currentKey;

  keys = [[doubleEmails allKeys] objectEnumerator];
  while ((currentKey = [keys nextObject]))
    if ([[doubleEmails objectForKey: currentKey] count] < 2)
      [doubleEmails removeObjectForKey: currentKey];
}

- (NSDictionary *) detectDoubleEmailsFromRecords: (NSArray *) records
{
  NSMutableDictionary *doubleEmails;
  unsigned int count, max;

  doubleEmails = [NSMutableDictionary dictionaryWithCapacity: [records count]];
  max = [records count];
  for (count = 0; count < max; count++)
    [self feedDoubleEmails: doubleEmails
	  withRecord: [records objectAtIndex: count]];
  [self cleanupSingleRecords: doubleEmails];

  return doubleEmails;
}

- (NSArray *) fetchCardsInListsFromFolder: (GCSFolder *) folder
{
  EOQualifier *qualifier;
  NSMutableArray *cardsInLists;
  NSDictionary *currentRecord;
  NSArray *records;
  NSEnumerator *recordsEnum;
  NGVList *list;

  cardsInLists = [NSMutableArray array];

  qualifier = [EOQualifier qualifierWithQualifierFormat: @"c_component = %@",
                           @"vlist"];
  records = [folder fetchFields: [NSArray arrayWithObject: @"c_content"]
              matchingQualifier: qualifier];
  recordsEnum = [records objectEnumerator];
  while ((currentRecord = [recordsEnum nextObject]))
    {
      list = [NGVList parseSingleFromSource:
                [currentRecord objectForKey: @"c_content"]];
      [cardsInLists addObjectsFromArray: [list cardNames]];
    }

  return cardsInLists;
}

- (void) removeRecord: (NSString *) recordName
	    fromTable: (NSString *) tableName
	andQuickTable: (NSString *) quickTableName
	 usingChannel: (EOAdaptorChannel *) channel
{
  NSString *delSql;

  /* We remove the records without regards to c_deleted because we really want
     to recover table space. */

  delSql = [NSString stringWithFormat: @"DELETE FROM %@"
		     @" WHERE c_name = '%@'",
		     tableName, recordName];
  [channel evaluateExpressionX: delSql];
  delSql = [NSString stringWithFormat: @"DELETE FROM %@"
		     @" WHERE c_name = '%@'",
		     quickTableName, recordName];
  [channel evaluateExpressionX: delSql];
}

- (void) removeRecords: (NSArray *) recordNames
	    fromFolder: (GCSFolder *) folder
{
  EOAdaptorChannel *channel;
  EOAdaptorContext *context;
  NSString *tableName, *quickTableName, *currentRecordName;
  NSEnumerator *recordsEnum;

  fprintf (stderr, "Removing %d records...\n", [recordNames count]);

  channel = [folder acquireStoreChannel];
  context = [channel adaptorContext];
  [context beginTransaction];

  tableName = [folder storeTableName];
  quickTableName = [folder quickTableName];

  recordsEnum = [recordNames objectEnumerator];
  while ((currentRecordName = [recordsEnum nextObject]))
    [self removeRecord: currentRecordName
	  fromTable: tableName andQuickTable: quickTableName
	  usingChannel: channel];

  [context commitTransaction];
  [folder releaseChannel: channel];
}

- (NSArray *) namesOfRecords: (NSArray *) records
	       differentFrom: (unsigned int) keptRecord
		       count: (unsigned int) max
{
  NSMutableArray *recordsToRemove;
  NSDictionary *currentRecord;
  unsigned int count;

  recordsToRemove = [NSMutableArray arrayWithCapacity: (max - 1)];
  for (count = 0; count < max; count++)
    {
      if (count != keptRecord)
	{
	  currentRecord = [records objectAtIndex: count];
	  [recordsToRemove
	    addObject: [currentRecord objectForKey: @"c_name"]];
	}
    }

  return recordsToRemove;
}

- (NSArray *) records: (NSArray *) records
     withLowestScores: (unsigned int *) scores
		count: (unsigned int) max
{
  unsigned int count, highestScore;
  int highestScoreRecord;

  highestScore = 0;
  highestScoreRecord = -1;
  for (count = 0; count < max; count++)
    {
      if (scores[count] > highestScore)
	{
	  highestScore = scores[count];
	  highestScoreRecord = count;
	}
    }

  if (highestScoreRecord == -1)
    highestScoreRecord = 0;

  return [self namesOfRecords: records
	       differentFrom: highestScoreRecord
	       count: max];
}

- (int) mostModifiedRecord: (NSArray *) records
                     count: (unsigned int) max
{
  unsigned int mostModified, count, highestVersion, version;
  NSNumber *currentVersion;

  mostModified = 0;

  highestVersion = 0;
  for (count = 0; count < max; count++)
    {
      currentVersion
	= [[records objectAtIndex: count] objectForKey: @"c_version"];
      version = [currentVersion intValue];
      if (version > highestVersion)
	{
	  mostModified = count;
	  highestVersion = version;
	}
    }

  return mostModified;
}

- (int) amountOfFilledQuickFields: (NSDictionary *) record
{
  static NSArray *quickFields = nil;
  id value;
  int amount, count, max;

  amount = 0;

  if (!quickFields)
    {
      quickFields = [NSArray arrayWithObjects: @"c_givenname", @"c_cn",
			     @"c_sn", @"c_screenname", @"c_l", @"c_mail",
			     @"c_o", @"c_ou", @"c_telephoneNumber", nil];
      [quickFields retain];
    }

  max = [quickFields count];
  for (count = 0; count < max; count++)
    {
      value = [record objectForKey: [quickFields objectAtIndex: count]];
      if ([value isKindOfClass: [NSString class]])
	{
	  if ([value length])
	    amount++;
	}
      else if ([value isKindOfClass: [NSNumber class]])
	amount++;
    }

  return amount;
}

- (int) recordWithTheMostQuickFields: (NSArray *) records
                               count: (unsigned int) max
{
  int mostQuickFields, count, highestQFields, currentQFields;

  mostQuickFields = 0;

  highestQFields = 0;
  for (count = 0; count < max; count++)
    {
      currentQFields
	= [self amountOfFilledQuickFields: [records objectAtIndex: count]];
      if (currentQFields > highestQFields)
	{
	  mostQuickFields = count;
	  highestQFields = currentQFields;
	}
    }

  return mostQuickFields;
}

- (int) linesInContent: (NSString *) content
{
  int nbrLines;
  NSArray *lines;

  lines = [content componentsSeparatedByString: @"\n"];
  nbrLines = [lines count];

  /* sometimes the end line will finish with a CRLF, we fix this */
  if (![[lines objectAtIndex: nbrLines - 1] length])
    nbrLines--;

  return nbrLines;
}

- (int) mostCompleteRecord: (NSArray *) records
			      count: (unsigned int) max
{
  int mostComplete, count, highestLines, lines;
  NSString *content;

  mostComplete = 0;

  highestLines = 0;
  for (count = 0; count < max; count++)
    {
      content = [[records objectAtIndex: count] objectForKey: @"c_content"];
      lines = [self linesInContent: content];
      if (lines > highestLines)
	{
	  mostComplete = count;
	  highestLines = lines;
	}
    }

  return mostComplete;
}

- (int)      record: (NSArray *) records
  referencedInLists: (NSArray *) cardsInLists
{
  int recordIndex, count, max;
  NSDictionary *currentRecord;

  recordIndex = -1;

  max = [records count];
  count = 0;

  while (recordIndex == -1 && count < max)
    {
      currentRecord = [records objectAtIndex: count];
      if ([cardsInLists
            containsObject: [currentRecord objectForKey: @"c_name"]])
        recordIndex = count;
      else
        count++;
    }

  return recordIndex;
}

- (void) assignScores: (unsigned int *) scores
	    toRecords: (NSArray *) records
		count: (unsigned int) max
     withCardsInLists: (NSArray *) cardsInLists
{
  int recordIndex;

  recordIndex = [self mostModifiedRecord: records count: max];
  (*(scores + recordIndex))++;
  recordIndex = [self mostCompleteRecord: records count: max];
  (*(scores + recordIndex)) += 2;
  recordIndex = [self recordWithTheMostQuickFields: records count: max];
  (*(scores + recordIndex)) += 3;

  /* TODO: this method is ugly. Instead of replacing the card references in the
     list with the most useful one, we remove the cards that are not
     mentionned in the list. */
  recordIndex = [self record: records referencedInLists: cardsInLists];
  if (recordIndex > -1)
    (*(scores + recordIndex)) += 6;
}

- (NSArray *) detectRecordsToRemove: (NSDictionary *) records
                   withCardsInLists: (NSArray *) cardsInLists
{
  NSMutableArray *recordsToRemove;
  NSEnumerator *recordsEnum;
  NSArray *currentRecords;
  unsigned int *scores, max;

  recordsToRemove = [NSMutableArray arrayWithCapacity: [records count] * 4];
  recordsEnum = [[records allValues] objectEnumerator];

  while ((currentRecords = [recordsEnum nextObject]))
    {
      max = [currentRecords count];
      scores = NSZoneCalloc (NULL, max, sizeof (unsigned int));
      [self assignScores: scores
               toRecords: currentRecords count: max
        withCardsInLists: cardsInLists];
      [recordsToRemove addObjectsFromArray: [self records: currentRecords
						  withLowestScores: scores
						  count: max]];
      NSZoneFree (NULL, scores);
    }

  return recordsToRemove;
}

- (BOOL) removeDoublesFromFolder: (GCSFolder *) folder
{
  NSArray *fields, *records, *recordsToRemove;
  EOQualifier *qualifier;
  BOOL rc;

  fields = [NSArray arrayWithObjects: @"c_name", @"c_givenname", @"c_cn",
		    @"c_sn", @"c_screenname", @"c_l", @"c_mail", @"c_o",
		    @"c_ou", @"c_telephoneNumber", @"c_content", @"c_version",
		    @"c_creationdate", @"c_lastmodified", nil];
  qualifier = [EOQualifier qualifierWithQualifierFormat: @"c_component = %@",
                           @"vcard"];
  records = [folder fetchFields: fields matchingQualifier: qualifier];

  if (records)
    {
      rc = YES;
      recordsToRemove = [self detectRecordsToRemove:
                                [self detectDoubleEmailsFromRecords: records]
                                   withCardsInLists:
                                [self fetchCardsInListsFromFolder: folder]];
      if ([recordsToRemove count])
        {
          [self removeRecords: recordsToRemove fromFolder: folder];
          fprintf (stderr, "Removed %d records from %d.\n",
                   [recordsToRemove count], [records count]);
        }
      else
        fprintf (stderr, "No record to remove. %d records kept.\n",
                 [records count]);
    }
  else
    {
      fprintf (stderr, "Unable to fetch required fields from folder.\n");
      rc = NO;
    }

  return NO;
}

- (BOOL) processFolder: (NSString *) folderId
		ofUser: (NSString *) username
	       withFoM: (GCSFolderManager *) fom
{
  NSString *folderPath;
  GCSFolder *folder;
  BOOL rc;

  folderPath = [NSString stringWithFormat: @"/Users/%@/Contacts/%@",
			 username, folderId];
  folder = [fom folderAtPath: folderPath];
  if (folder)
    rc = [self removeDoublesFromFolder: folder];
  else
    {
      fprintf (stderr, "Folder '%s' of user '%s' not found.\n",
	       [folderId cStringUsingEncoding: NSUTF8StringEncoding],
               [username cStringUsingEncoding: NSUTF8StringEncoding]);
      rc = NO;
    }

  return rc;
}

- (BOOL) runWithFolder: (NSString *) folder
	       andUser: (NSString *) username
{
  GCSFolderManager *fom;
  BOOL rc;

  fom = [GCSFolderManager defaultFolderManager];
  if (fom)
    rc = [self processFolder: folder ofUser: username
	       withFoM: fom];
  else
    rc = NO;

  return rc;
}

@end

static void
Usage (const char *name)
{
  const char *slash, *start;

  slash = strrchr (name, '/');
  if (slash)
    start = slash + 1;
  else
    start = name;
  fprintf (stderr, "Usage: %s USER FOLDER\n\n"
	   "         USER       the owner of the contact folder\n"
	   "         FOLDER     the id of the folder to clean up\n",
	   start);
}

int
main (int argc, char **argv, char **env)
{
  NSAutoreleasePool *pool;
  SOGoDoublesRemover *remover;
  int rc;

  rc = -1;

  pool = [NSAutoreleasePool new];

  if (argc > 2)
    {
      remover = [SOGoDoublesRemover new];
      if ([remover runWithFolder: [NSString stringWithFormat: @"%s", argv[2]]
		   andUser: [NSString stringWithFormat: @"%s", argv[1]]])
	rc = 0;
      [remover release];
    }
  else
    Usage (argv[0]);

  [pool release];

  return rc;
}
