/* SOGoMailObject+Draft.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2017 Inverse inc.
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

#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeType.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserDefaults.h>

#import "NSData+Mail.h"
#import "NSData+SMIME.h"
#import "NSString+Mail.h"
#import "SOGoMailAccount.h"
#import "SOGoMailObject+Draft.h"
#import "SOGoMailReply.h"

#define MAX_FILENAME_LENGTH 64

//
//
//
@implementation SOGoMailObject (SOGoDraftObjectExtensions)

- (NSString *) subjectForReply
{
  static NSString *replyPrefixes[] = {
    @"Re:", // regular
    @"RE:", // Outlook v11 (English?)
    @"AW:", // German Outlook v11
    @"Re[", // numbered Re, eg "Re[2]:"
    nil
  };
  BOOL hasPrefix;
  NSUInteger i;
  NSString *subject, *newSubject;

  hasPrefix = NO;

  subject = [self decodedSubject];
  if (![subject length]) subject = @"";

  i = 0;
  while (!hasPrefix && replyPrefixes[i])
    if ([subject hasPrefix: replyPrefixes[i]])
      hasPrefix = YES;
    else
      i++;

  if (hasPrefix)
    newSubject = subject;
  else
    newSubject = [NSString stringWithFormat: @"Re: %@", subject];

  return newSubject;
}

//
//
//
- (NSString *) _convertRawContentForEditing: (NSString *) raw
                                    rawHtml: (BOOL) html
{
  NSString *rc;
  SOGoUserDefaults *ud;
  BOOL htmlComposition;

  ud = [[context activeUser] userDefaults];
  htmlComposition = [[ud mailComposeMessageType] isEqualToString: @"html"];
  if (html && !htmlComposition)
    rc = [raw htmlToText];
  else if (!html && htmlComposition)
    rc = [[raw stringByEscapingHTMLString] stringByConvertingCRLNToHTML];
  else
    rc = raw;

  return rc;
}

//
//
//
- (NSString *) _contentForEditingFromKeys: (NSArray *) keys
{
  NSString *rawPart, *content, *contentKey;
  SOGoUserDefaults *ud;
  NSDictionary *parts;
  NSArray *types;
  NSData *data;

  BOOL htmlComposition, htmlContent;
  NSUInteger index, indexTextPlain;

  content = @"";

  if ([keys count])
    {
      ud = [[context activeUser] userDefaults];
      htmlComposition = [[ud mailComposeMessageType] isEqualToString: @"html"];
      htmlContent = NO;
      types = [keys objectsForKey: @"mimeType" notFoundMarker: @""];

      if (htmlComposition)
        {
          // Prefer HTML content
          indexTextPlain = [types indexOfObject: @"text/plain"];
          index = [types indexOfObject: @"text/html"];
          // Ticket https://bugs.sogo.nu/view.php?id=5983
          // In this case, the first HTML content is used, but it can be the previous forwarded mail
          // We check if there is a text/plain before text/html in the types array
          // is this case, the text/plain is used prior to text/html.
          if (index != NSNotFound // There is a text/html part
              && indexTextPlain != NSNotFound  // There is a text/plain part
              && indexTextPlain < index  // text/plain is before text/html
              && (indexTextPlain + 1) < [keys count] // text/plain is not the last part of the mail
              && [[[keys objectAtIndex: (indexTextPlain + 1)] objectForKey:@"mimeType"] rangeOfString:@"text/plain"].location != NSNotFound //  The text/plain is followed up by another text/plain
              )
            index = indexTextPlain;
          else if (index == NSNotFound)
            index = [types indexOfObject: @"text/plain"];
          else
            htmlContent = YES;
        }
      else
        {
          // Prefer text content
          index = [types indexOfObject: @"text/plain"];
          if (index == NSNotFound)
            {
              index = [types indexOfObject: @"text/html"];
              htmlContent = YES;
            }
        }

      if (index != NSNotFound)
        {
          contentKey = [keys objectAtIndex: index];
          parts = [self fetchPlainTextStrings:
                     [NSArray arrayWithObject: contentKey]];
          if ([parts count] > 0)
            {
              rawPart = [[parts allValues] objectAtIndex: 0];
              content = [self _convertRawContentForEditing: rawPart 
                                                   rawHtml: htmlContent];
            }
        }
    }

  // We strip charset= information from HTML content to avoid SOGo setting
  // the encoding of the final mail to UTF-8 while keeping charset="iso-8859-1"
  // in the HTML meta headers, for example. That would cause encoding display
  // issues with most MUAs.
  data = [[content dataUsingEncoding: NSUTF8StringEncoding] sanitizedContentUsingVoidTags: nil];
  content = [[NSString alloc] initWithData: data  encoding: NSUTF8StringEncoding];

  return [content autorelease];
}

//
//
//
- (NSString *) _preferredContentFromPart: (id) thePart
                               favorHTML: (BOOL) favorHTML
{
  NSString *type, *subtype;
  id body;

  if ([thePart isKindOfClass: [NGMimeBodyPart class]])
    {
      type = [[thePart contentType] type];
      subtype = [[thePart contentType] subType];
      body = [thePart body];

      if ([type isEqualToString: @"text"])
        {
          if ([subtype isEqualToString: @"html"] && favorHTML)
            return [[body stringByEscapingHTMLString] stringByConvertingCRLNToHTML];
          else if ([subtype isEqualToString: @"html"] && !favorHTML)
            return [body htmlToText];
          else if ([subtype isEqualToString: @"plain"])
            return body;
        }
    }
  else if ([thePart isKindOfClass: [NGMimeMultipartBody class]])
    {
      NSArray *parts;
      int i;

      parts = [thePart parts];
      for (i = 0; i < [parts count]; i++)
        {
          type = [[[parts objectAtIndex: i] contentType] type];

          if ([type isEqualToString: @"text"] || [type isEqualToString: @"multipart"])
            return [self _preferredContentFromPart: [parts objectAtIndex: i]
                                         favorHTML: favorHTML];
        }
    }

  return nil;
}

//
//
//
- (NSString *) _contentForEditingFromEncryptedMail
{
  NSData *certificate;

  certificate = [[self mailAccountFolder] certificate];

  if (certificate)
    {
      SOGoUserDefaults *ud;
      NGMimeMessage *m;

      m = [[self content] messageFromEncryptedDataAndCertificate: certificate];
      ud = [[context activeUser] userDefaults];

      return [self _preferredContentFromPart: [m body]
                                   favorHTML: [[ud mailComposeMessageType] isEqualToString: @"html"]];
    }

  return nil;
}


//
//
//
- (NSString *) _contentForEditingFromOpaqueSignedMail
{
  SOGoUserDefaults *ud;
  NGMimeMessage *m;

  m = [[self content] messageFromOpaqueSignedData];
  ud = [[context activeUser] userDefaults];

  return [self _preferredContentFromPart: [m body]
                               favorHTML: [[ud mailComposeMessageType] isEqualToString: @"html"]];

  return nil;
}

//
//
//
- (NSString *) contentForEditing
{
  NSMutableArray *keys;
  NSString *output;

  output = nil;

  if ([self isEncrypted])
    output = [self _contentForEditingFromEncryptedMail];
  else if ([self isOpaqueSigned])
    output = [self _contentForEditingFromOpaqueSignedMail];

  // If not encrypted or if decryption failed, we fallback
  // to the normal content fetching code.
  if (!output)
    {
      keys = [NSMutableArray array];
      [self addRequiredKeysOfStructure: [self bodyStructure]
                                  path: @""
                               toArray: keys
                         acceptedTypes: [NSArray arrayWithObjects: @"text/plain", @"text/html", nil]
                              withPeek: NO];
      output = [self _contentForEditingFromKeys: keys];
    }

  return output;
}

//
//
//
- (NSString *) contentForReply
{
  NSString *pageName;
  SOGoMailReply *page;
  SOGoUserDefaults *userDefaults;

  userDefaults = [[context activeUser] userDefaults];
  pageName = [NSString stringWithFormat: @"SOGoMail%@Reply",
		       [userDefaults language]];
  page = [[WOApplication application] pageWithName: pageName
				      inContext: context];
  [page setSourceMail: self];
  [page setOutlookMode: [userDefaults mailUseOutlookStyleReplies]];
  [page setReplyPlacement: [userDefaults mailReplyPlacement]];
  [page setSignaturePlacement: [userDefaults mailSignaturePlacement]];
  
  return [[page generateResponse] contentAsString];
}

//
//
//
- (NSString *) filenameForForward
{
  NSString *subject;
  NSMutableString *newSubject;
  static NSString *sescape[] = { 
    @"/", @"..", @"~", @"\"", @"'", @" ", @".", nil 
  };
  NSUInteger count, length;

  subject = [self decodedSubject];
  length = [subject length];
  if (!length)
    {
      subject = @"forward";
      length = [subject length];
    }

  if (length > MAX_FILENAME_LENGTH)
    length = MAX_FILENAME_LENGTH;
  newSubject = [NSMutableString
		 stringWithString: [subject substringToIndex: length]];
  count = 0;
  while (sescape[count])
    {
      [newSubject replaceString: sescape[count]
		  withString: @"_"];
      count++;
    }
  [newSubject appendString: @".eml"];

  return newSubject;
}

//
//
//
- (NSString *) subjectForForward
{
  NSString *subject, *newSubject;

  subject = [self decodedSubject];
  if ([subject length] > 0)
    newSubject = [NSString stringWithFormat: @"Fwd: %@", subject];
  else
    newSubject = subject;

  return newSubject;
}

//
//
//
- (NSString *) contentForInlineForward
{
  SOGoUserDefaults *userDefaults;
  NSString *pageName;
  SOGoMailForward *page;

  userDefaults = [[context activeUser] userDefaults];
  pageName = [NSString stringWithFormat: @"SOGoMail%@Forward",
		       [userDefaults language]];
  page = [[WOApplication application] pageWithName: pageName
				      inContext: context];
  [page setSourceMail: self];
  [page setSignaturePlacement: [userDefaults mailSignaturePlacement]];

  return [[page generateResponse] contentAsString];
}

@end
