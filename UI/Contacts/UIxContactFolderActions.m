/*
  Copyright (C) 2006-2022 Inverse inc.

  This file is part of SOGo

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
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
#import <NGObjWeb/WOResponse.h>
#define COMPILING_NGOBJWEB 1 /* we want httpRequest for parsing multi-part
                                form data */
#import <NGObjWeb/WORequest.h>
#undef COMPILING_NGOBJWEB
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGHttp/NGHttpRequest.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeHeaderFields.h>

#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>
#import <GDLContentStore/GCSFolder.h>

#import <Contacts/NSDictionary+LDIF.h>

#import <SoObjects/Contacts/NGVCard+SOGo.h>
#import <SoObjects/Contacts/NGVList+SOGo.h>
#import <SoObjects/Contacts/SOGoContactGCSEntry.h>
#import <SoObjects/Contacts/SOGoContactLDIFEntry.h>
#import <SoObjects/Contacts/SOGoContactGCSList.h>
#import <SoObjects/Contacts/SOGoContactGCSFolder.h>

#import <SOGo/NSString+Utilities.h>

#import "UIxContactFolderActions.h"

static NSArray *photoTags = nil;

@implementation UIxContactFolderActions

+ (void) initialize
{
  if (!photoTags)
    {
      photoTags = [[NSArray alloc] initWithObjects: @"jpegphoto", @"photo", @"thumbnailphoto", nil];
    }
}

/* actions */

- (id <WOActionResults>) exportAction
{
  WOResponse *response;
  NSArray *contactsId;
  NSEnumerator *uids;
  NSString *uid, *filename, *disposition;
  id currentChild;
  SOGoContactGCSFolder *sourceFolder;
  NSMutableString *content;

  content = [NSMutableString string];
  sourceFolder = [self clientObject];
  contactsId = [[[[context request] contentAsString] objectFromJSONString] objectForKey: @"uids"];

  if (!contactsId)
    contactsId = [sourceFolder toOneRelationshipKeys];

  uids = [contactsId objectEnumerator];
  while ((uid = [uids nextObject]))
    {
      currentChild = [sourceFolder lookupName: uid
                                    inContext: [self context]
                                      acquire: NO];
      if ([currentChild respondsToSelector: @selector (vCard)])
        [content appendFormat: @"%@", [[currentChild ldifRecord] ldifRecordAsString]];
      else if ([currentChild respondsToSelector: @selector (vList)])
        [content appendFormat: @"%@", [[currentChild vList] ldifString]];
      [content appendString: @"\n"];
    }

  response = [context response];
  [response setHeader: @"application/directory; charset=utf-8"
               forKey: @"content-type"];
  filename = [NSString stringWithFormat: @"%@.ldif",
                       [[sourceFolder displayName] asQPSubjectString: @"utf-8"]];
  disposition = [NSString stringWithFormat: @"attachment; filename=\"%@\"", filename];
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
  NSString *filename, *fileContent;
  int imported = 0;


  request = [context request];
  rc = [NSMutableDictionary dictionary];
  data = [[request httpRequest] body];

  // We got an exception, that means the file upload limit
  // has been reached.
  if ([data isKindOfClass: [NSException class]])
    {
      response = [self responseWithStatus: 507];
      return response;
    }

  data = [[data parts] lastObject];
  filename = [(NGMimeContentDispositionHeaderField *)[data headerForKey: @"content-disposition"] filename];
  data = [data body];

  fileContent = [[NSString alloc] initWithData: (NSData *) data
                                      encoding: NSUTF8StringEncoding];
  [fileContent autorelease];

  if (fileContent && [fileContent length])
    {
      if ([fileContent hasPrefix: @"dn:"] || [filename hasSuffix: @".ldif"])
        imported = [self importLdifData: fileContent];
      else if ([fileContent hasPrefix: @"BEGIN:"])
        imported = [self importVcardData: fileContent];
      else
        imported = 0;
    }

  [rc setObject: [NSNumber numberWithInt: imported]  forKey: @"imported"];

  response = [self responseWithStatus: 200];
  [response setHeader: @"text/html"  forKey: @"content-type"];
  [(WOResponse*)response appendContentString: [rc jsonRepresentation]];

  return response;
}

- (int) importLdifData: (NSString *) ldifData
{
  NSMutableArray *ldifListEntries;
  NSMutableDictionary *entry, *encodedEntry;
  SOGoContactLDIFEntry *ldifEntry;
  NSArray *ldifContacts, *lines;
  EOAdaptorChannel *channel;
  GCSFolder *gcsFolder;
  SOGoContactGCSFolder *folder;
  NSEnumerator *keyEnumerator;
  NSString *key, *uid, *line;
  NGVCard *vCard;
  NGVList *vList;
  id value, values;

  NSRange r;
  int i, j, count, linesCount, len;
  int rc;

  folder = [self clientObject];
  ldifListEntries = [NSMutableArray array];
  ldifContacts = [ldifData componentsSeparatedByString: @"\ndn"];
  count = [ldifContacts count];
  rc = 0;

  for (i = 0; i < count; i++)
    {
      encodedEntry = [NSMutableDictionary dictionary];
      lines = [[ldifContacts objectAtIndex: i]
               componentsSeparatedByString: @"\n"];

      key = NULL;
      linesCount = [lines count];
      for (j = 0; j < linesCount; j++)
        {
          line = [lines objectAtIndex: j];
          len = [line length];

          /* we check for trailing \r and we strip them */
          if (len && [line characterAtIndex: len-1] == '\r')
            line = [line substringToIndex: len-1];

          /* skip embedded comment lines */
          if ([line hasPrefix: @"#"])
            {
              key = NULL;
              continue;
            }

          if (j == 0 && ![line hasPrefix: @"dn:"])
            // Because we splitted contacts on "<LF> + dn", we need to restore the dn prefix,
            // unless it's the first contact of the file, in which case it still has the dn prefix.
            line = [NSString stringWithFormat: @"dn%@", line];

          /* handle continuation lines */
          if ([line hasPrefix: @" "])
            {
              if (key != NULL)
                {
                  values = [encodedEntry objectForKey: key];
                  if ([values isKindOfClass: [NSArray class]])
                    {
                      // Multiple values for key
                      value = [[values lastObject] stringByAppendingString: [line substringFromIndex: 1]];
                      [values replaceObjectAtIndex: [values count] - 1
                                        withObject: value];
                    }
                  else
                    {
                      // Single value for key
                      value = [values stringByAppendingString: [line substringFromIndex: 1]];
                      [encodedEntry setValue: value forKey: key];
                    }
                }
              continue;
            }

          r = [line rangeOfString: @": "];
	  if (r.location != NSNotFound)
            {
              key = [[line substringToIndex: r.location] lowercaseString];
              value = [line substringFromIndex: NSMaxRange(r)];

              if ([key length] == 0)
                key = @"dn";

              if ((values = [encodedEntry objectForKey: key]))
                {
                  if (![values isKindOfClass: [NSArray class]])
                    values = [NSMutableArray arrayWithObject: values];
                  [values addObject: value];
                  [encodedEntry setValue: values forKey: key];
                }
              else
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
          values = [encodedEntry valueForKey: key];
          if ([key hasSuffix: @":"])
            {
              key = [key substringToIndex: [key length] - 1];
              if ([photoTags containsObject: key])
                values = [values dataByDecodingBase64];
              else if ([values isKindOfClass: [NSArray class]])
                {
                  for (j = 0; j < [values count]; j++)
                    {
                      value = [values objectAtIndex: j];
                      value = [value stringByDecodingBase64];
                      [values replaceObjectAtIndex: j
                                        withObject: value];
                    }
                }
              else
                values = [values stringByDecodingBase64];
            }

          // Standard key recognized in NGCards
          if ([photoTags containsObject: key])
            key = @"photo";

          [entry setValue: values forKey: key];
        }

      if ([entry objectForKey: @"dn"])
        {
          uid = [folder globallyUniqueObjectId];
          ldifEntry = [SOGoContactLDIFEntry contactEntryWithName: uid
                                                   withLDIFEntry: entry
                                                     inContainer: folder];
          if (ldifEntry)
            {
              if ([ldifEntry isList])
                {
                  // Postpone importation of lists
                  [ldifListEntries addObject: ldifEntry];
                }
              else
                {
                  vCard = [ldifEntry vCard];
                  if ([self importVcard: vCard])
                    {
                      rc++;
                    }
                }
            }
        }
    }

  // Force update of quick table
  gcsFolder = [folder ocsFolder];
  channel = [gcsFolder acquireQuickChannel];
  [[channel adaptorContext] commitTransaction];
  [gcsFolder releaseChannel: channel];

  // Convert groups to vLists
  count = [ldifListEntries count];
  for (i = 0; i < count; i++)
    {
      vList = [[ldifListEntries objectAtIndex: i] vList];
      if ([self importVlist: vList])
        rc++;
    }

  return rc;
}

- (int) importVcardData: (NSString *) vcardData
{
  NGVList *vList;
  NSAutoreleasePool *pool;
  NSArray *allCards;
  NSMutableArray *allLists;
  int rc, count, i;

  rc = 0;

  pool = [[NSAutoreleasePool alloc] init];
  allCards = [NGVCard parseFromSource: vcardData];
  allLists = [NSMutableArray array];

  count = [allCards count];
  if (allCards && count)
    {
      for (i = 0; i < count; i++)
	{
          // Postpone importation of lists
	  if ([self importVcard: [allCards objectAtIndex: i]
                        andLists: allLists])
            rc++;
        }
    }

  // Import vLists
  count = [allLists count];
  if (count)
    {
      for (i = 0; i < count; i++)
	{
	  vList = [allLists objectAtIndex: i];
          if ([self importVlist: vList])
            rc++;
	}
    }

  RELEASE(pool);

  return rc;
}

- (BOOL) importVcard: (NGVCard *) card
{
  return [self importVcard: card
                  andLists: nil];
}

- (BOOL) importVcard: (NGVCard *) card
            andLists: (NSMutableArray *) lists
{
  BOOL rc;
  SOGoContactGCSFolder *folder;
  SOGoContactGCSEntry *contact;
  NGVList *list;
  NSAutoreleasePool *pool;
  NSString *uid;

  rc = NO;

  if (card)
    {
      pool = [[NSAutoreleasePool alloc] init];
      folder = [self clientObject];

      uid = [card uid];
      if (![uid length])
        {
          // TODO: shall we add .vcf as in [SOGoContactGCSEntry copyToFolder:]
          uid = [folder globallyUniqueObjectId];
          [card setUid: uid];
        }

      if ([[card tag] isEqualToString: @"VLIST"])
        {
          list = [NGVList parseSingleFromSource: [card versitString]];
          [lists addObject: list];
        }
      else
        {
          contact = [SOGoContactGCSEntry objectWithName: uid
                                        inContainer: folder];
          [contact setIsNew: YES];
          [contact saveComponent: card];
          rc = YES;
        }

      RELEASE(pool);
    }

  return rc;
}

 - (BOOL) importVlist: (NGVList *) list
{
  SOGoContactGCSFolder *folder;
  SOGoContactGCSList *contact;
  NSAutoreleasePool *pool;
  NSString *uid;

  BOOL rc = NO;

  if (list)
    {
      pool = [[NSAutoreleasePool alloc] init];
      folder = [self clientObject];

      uid = [list uid];
      if (![uid length])
        {
          // TODO: shall we add .vcf as in [SOGoContactGCSEntry copyToFolder:]
          uid = [folder globallyUniqueObjectId];
          [list setUid: uid];
        }
      contact = [SOGoContactGCSList objectWithName: uid
                                       inContainer: folder];
      [contact setIsNew: YES];
      [contact saveComponent: list];

      rc = YES;
      RELEASE(pool);
    }

  return rc;
}

@end /* UIxContactFolderActions */
