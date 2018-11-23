/*
  Copyright (C) 2006-2016 Inverse inc.

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
  NSString *fileContent;
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

  data = [[[data parts] lastObject] body];

  fileContent = [[NSString alloc] initWithData: (NSData *) data 
                                      encoding: NSUTF8StringEncoding];
  [fileContent autorelease];

  if (fileContent && [fileContent length])
    {
      if ([fileContent hasPrefix: @"dn:"])
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
  NSMutableDictionary *entry, *encodedEntry;
  SOGoContactLDIFEntry *ldifEntry;
  NSArray *ldifContacts, *lines;
  SOGoContactGCSFolder *folder;
  NSEnumerator *keyEnumerator;
  NSString *key, *uid, *line;
  NGVCard *vCard;
  id value;

  NSRange r;
  int i, j, count, linesCount, len;
  int rc;

  folder = [self clientObject];
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

          r = [line rangeOfString: @": "];
	  if (r.location != NSNotFound)
            {
              key = [[line substringToIndex: r.location] lowercaseString];
              value = [line substringFromIndex: NSMaxRange(r)];

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
	      if ([photoTags containsObject: key])
		value = [value dataByDecodingBase64];
	      else
		value = [value stringByDecodingBase64];
            }

	  // Standard key recognized in NGCards
	  if ([photoTags containsObject: key])
	    key = @"photo";

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
  NSAutoreleasePool *pool;
  NSArray *allCards;
  int rc, count;

  rc = 0;

  pool = [[NSAutoreleasePool alloc] init];
  allCards = [NGVCard parseFromSource: vcardData];

  count = [allCards count];
  if (allCards && count)
    {
      int i;

      for (i = 0; i < count; i++)
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

  RELEASE(pool);

  return rc;
}

- (BOOL) importVcard: (NGVCard *) card
{
  SOGoContactGCSFolder *folder;
  SOGoContactGCSEntry *contact;
  NSAutoreleasePool *pool;
  NSString *uid;

  BOOL rc = NO;

  if (card)
    {
      pool = [[NSAutoreleasePool alloc] init];
      folder = [self clientObject];
      uid = [folder globallyUniqueObjectId];

      [card setUid: uid];
      // TODO: shall we add .vcf as in [SOGoContactGCSEntry copyToFolder:]
      contact = [SOGoContactGCSEntry objectWithName: uid
                                        inContainer: folder];
      [contact setIsNew: YES];
      
      [contact saveComponent: card];
      
      rc = YES;
      RELEASE(pool);
    }

  return rc;
}

@end /* UIxContactFolderActions */
