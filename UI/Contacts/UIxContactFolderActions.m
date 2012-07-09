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

#import <Foundation/Foundation.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/NSString+Utilities.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NGBase64Coding.h>

#import <Contacts/SOGoContactObject.h>
#import <Contacts/SOGoContactFolder.h>
#import <Contacts/SOGoContactFolders.h>
#import <Contacts/NSDictionary+LDIF.h>

#import <SoObjects/Contacts/NGVCard+SOGo.h>
#import <SoObjects/Contacts/NGVList+SOGo.h>
#import <SoObjects/Contacts/SOGoContactGCSEntry.h>
#import <SoObjects/Contacts/SOGoContactLDIFEntry.h>
#import <SoObjects/Contacts/SOGoContactGCSList.h>
#import <SoObjects/Contacts/SOGoContactGCSFolder.h>
#import <GDLContentStore/GCSFolder.h>

#import "UIxContactFolderActions.h"

@implementation UIxContactFolderActions


/* actions */

- (id <WOActionResults>) exportAction
{
  WORequest *request;
  WOResponse *response;
  NSArray *contactsId;
  NSEnumerator *uids;
  NSString *uid, *filename, *disposition;
  id currentChild;
  SOGoContactGCSFolder *sourceFolder;
  NSMutableString *content;

  content = [NSMutableString string];
  request = [context request];
  sourceFolder = [self clientObject];
  contactsId = [request formValuesForKey: @"uid"];
  if (!contactsId)
    contactsId = [sourceFolder toOneRelationshipKeys];

  uids = [contactsId objectEnumerator];
  while ((uid = [uids nextObject]))
    {
      currentChild = [sourceFolder lookupName: uid
                                    inContext: [self context]
                                      acquire: NO];
      if ([currentChild respondsToSelector: @selector (vCard)])
        [content appendFormat: [[currentChild ldifRecord] ldifRecordAsString]];
      else if ([currentChild respondsToSelector: @selector (vList)])
        [content appendFormat: [[currentChild vList] ldifString]];
      [content appendString: @"\n"];
    }

  response = [context response];
  [response setHeader: @"application/octet-stream; charset=utf-8" 
               forKey: @"content-type"];
  filename = [NSString stringWithFormat: @"%@.ldif",
                       [sourceFolder displayName]];
  disposition = [NSString stringWithFormat: @"attachment; filename=\"%@\"", 
                          [filename asQPSubjectString: @"utf-8"]];
  [response setHeader: disposition forKey: @"Content-Disposition"];
  [response setContent: [content dataUsingEncoding: NSUTF8StringEncoding]];

  return response;
}

- (id <WOActionResults>) importAction
{
  WORequest *request;
  WOResponse *response;
  id data;
  NSMutableDictionary *rc;
  NSString *fileContent;
  int imported = 0;


  request = [context request];
  rc = [NSMutableDictionary dictionary];
  data = [request formValueForKey: @"contactsFile"];
  if ([data respondsToSelector: @selector(isEqualToString:)])
    fileContent = (NSString *) data;
  else
    {
      fileContent = [[NSString alloc] initWithData: (NSData *) data 
                                          encoding: NSUTF8StringEncoding];
      [fileContent autorelease];
    }

  if (fileContent && [fileContent length])
    {
      if ([fileContent hasPrefix: @"dn:"])
        imported = [self importLdifData: fileContent];
      else if ([fileContent hasPrefix: @"BEGIN:"])
        imported = [self importVcardData: fileContent];
      else
        imported = 0;
    }

  [rc setObject: [NSNumber numberWithInt: imported]
         forKey: @"imported"];

  response = [self responseWithStatus: 200];
  [response setHeader: @"text/html" 
               forKey: @"content-type"];
  [(WOResponse*)response appendContentString: [rc jsonRepresentation]];

  return response;
}

- (int) importLdifData: (NSString *) ldifData
{
  SOGoContactGCSFolder *folder;
  NSString *key, *value;
  NSArray *ldifContacts, *lines, *components;
  NSMutableDictionary *entry;
  NGVCard *vCard;
  NSString *uid;
  int i,j,count,linesCount;
  int rc = 0;

  folder = [self clientObject];
  ldifContacts = [ldifData componentsSeparatedByString: @"\ndn"];
  count = [ldifContacts count];

  for (i = 0; i < count; i++)
    {
      SOGoContactLDIFEntry *ldifEntry;
      NSEnumerator *keyEnumerator;
      NSMutableDictionary *encodedEntry;
      encodedEntry = [NSMutableDictionary dictionary];
      lines = [[ldifContacts objectAtIndex: i] 
               componentsSeparatedByString: @"\n"];

      key = NULL;
      linesCount = [lines count];
      for (j = 0; j < linesCount; j++)
        {
          NSString *line;
          line = [lines objectAtIndex: j];

          /* skip embedded comment lines */
          if ([line hasPrefix: @"#"])
            {
              key = NULL;
              continue;
            }

          /* handle continuation lines */
          if ([line hasPrefix: @" "])
            {
              if (key != NULL)
                {
                  value = [[encodedEntry valueForKey: key]
                           stringByAppendingString: [line substringFromIndex: 1]];
                  [encodedEntry setValue: value forKey: key];
                }
              continue;
            }

          components = [line componentsSeparatedByString: @": "];
          if ([components count] == 2)
            {
              key = [[components objectAtIndex: 0] lowercaseString];
              value = [components objectAtIndex: 1];

              if ([key length] == 0)
                key = @"dn";

              [encodedEntry setValue: value forKey: key];
            }
          else
            {
              break;
            }
        }

      /* decode Base64-encoded attributes */
      entry = [NSMutableDictionary dictionary];
      keyEnumerator = [encodedEntry keyEnumerator];
      while ((key = [keyEnumerator nextObject]))
        {
          value = [encodedEntry valueForKey: key];
          if ([key hasSuffix: @":"])
            {
              key = [key substringToIndex: [key length] - 1];
              value = [value stringByDecodingBase64];
            }
          [entry setValue: value forKey: key];
        }

      uid = [folder globallyUniqueObjectId];
      ldifEntry = [SOGoContactLDIFEntry contactEntryWithName: uid
                                               withLDIFEntry: entry
                                                 inContainer: folder];
      if (ldifEntry)
        {
          vCard = [ldifEntry vCard];
          if ([self importVcard: vCard])
            rc++;
          
        }
    }
  return rc;
}

- (int) importVcardData: (NSString *) vcardData
{
  NSArray *allCards;
  int rc;

  rc = 0;
  allCards = [NGVCard parseFromSource: vcardData];

  if (allCards && [allCards count])
    {
      int i;

      for (i = 0; i < [allCards count]; i++)
	{
	  if (![self importVcard: [allCards objectAtIndex: i]])
	    {
	      rc = 0;
	      break;
	    }
	  else
	    rc++;
	}
    }

  return rc;
}

- (BOOL) importVcard: (NGVCard *) card
{
  NSString *uid;
  SOGoContactGCSFolder *folder;
  SOGoContactGCSEntry *contact;
  BOOL rc = NO;

  if (card)
    {
      folder = [self clientObject];
      uid = [folder globallyUniqueObjectId];

      [card setUid: uid];
      contact = [SOGoContactGCSEntry objectWithName: uid
                                        inContainer: folder];
      [contact setIsNew: YES];
      
      [contact saveContentString: [card versitString]];
      
      rc = YES;
    }

  return rc;
}

@end /* UIxContactsListView */
