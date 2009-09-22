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

#import <Contacts/SOGoContactObject.h>
#import <Contacts/SOGoContactFolder.h>
#import <Contacts/SOGoContactFolders.h>

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
  id <WOActionResults> response;
  NSArray *contactsId;
  NSEnumerator *uids;
  NSString *uid, *filename;
  id currentChild;
  SOGoContactGCSFolder *sourceFolder;
  NSMutableString *content;

  content = [NSMutableString string];
  request = [context request];
  contactsId = [request formValuesForKey: @"uid"];
  if (contactsId)
    {
      sourceFolder = [self clientObject];
      uids = [contactsId objectEnumerator];
      while ((uid = [uids nextObject]))
        {
          currentChild = [sourceFolder lookupName: uid
                                        inContext: [self context]
                                          acquire: NO];
          if ([currentChild respondsToSelector: @selector (vCard)])
            [content appendFormat: [[currentChild vCard] ldifString]];
          else if ([currentChild respondsToSelector: @selector (vList)])
            [content appendFormat: [[currentChild vList] ldifString]];
        }
    }

  filename = [NSString stringWithFormat: @"attachment;filename=%@.ldif", 
              [self labelForKey: @"Contacts"]];
  response = [context response];
  [response setHeader: @"text/directory; charset=utf-8" 
               forKey: @"content-type"];
  [response setHeader: filename 
               forKey: @"Content-Disposition"];
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
      entry = [NSMutableDictionary dictionary];
      lines = [[ldifContacts objectAtIndex: i] 
               componentsSeparatedByString: @"\n"];

      linesCount = [lines count];
      for (j = 0; j < linesCount; j++)
        {
          components = [[lines objectAtIndex: j] 
                 componentsSeparatedByString: @": "];
          if ([components count] == 2)
            {
              key = [components objectAtIndex: 0];
              value = [components objectAtIndex: 1];

              if ([key length] == 0)
                key = @"dn";

              [entry setObject: value forKey: key];
            }
          else
            {
              break;
            }
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
  NGVCard *card;
  int rc;

  rc = 0;
  card = [NGVCard parseSingleFromSource: vcardData];
  if ([self importVcard: card])
    rc = 1;

  return rc;
}

- (BOOL) importVcard: (NGVCard *) card
{
  NSString *uid, *name;
  SOGoContactGCSFolder *folder;
  NSException *ex;
  BOOL rc = NO;

  if (card)
    {
      folder = [self clientObject];
      uid = [folder globallyUniqueObjectId];
      name = [NSString stringWithFormat: @"%@.vcf", uid];
      [card setUid: uid];
      ex = [[folder ocsFolder] writeContent: [card versitString]
                                     toName: name
                                baseVersion: 0];
      if (ex)
        NSLog (@"write failed: %@", ex);
      else
        rc = YES;
    }

  return rc;
}


@end /* UIxContactsListView */
