/*
  Copyright (C) 2017-2018 Inverse inc.

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSDictionary.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeHeaderFields.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeType.h>
#import <NGMail/NGMimeMessageParser.h>

#import <SoObjects/Mailer/NSData+SMIME.h>
#import <SoObjects/Mailer/NSString+Mail.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
#import <UI/MailerUI/WOContext+UIxMailer.h>

#import "UIxMailRenderingContext.h"
#import "UIxMailPartEncryptedViewer.h"

@implementation UIxMailPartEncryptedViewer

- (void) _attachmentIdsFromBodyPart: (id) thePart
                           partPath: (NSString *) thePartPath
{
  // Small hack to avoid SOPE's stupid behavior to wrap a multipart
  // object in a NGMimeBodyPart.
   if ([thePart isKindOfClass: [NGMimeBodyPart class]] &&
       [[[thePart contentType] type] isEqualToString: @"multipart"])
     thePart = [thePart body];

  if ([thePart isKindOfClass: [NGMimeBodyPart class]])
    {
      NSString *filename, *mimeType;

      mimeType = [[thePart contentType] stringValue];
      filename = [(NGMimeContentDispositionHeaderField *)[thePart headerForKey: @"content-disposition"] filename];

      if (!filename)
        filename = [mimeType asPreferredFilenameUsingPath: nil];

      if (filename)
        {
          [(id)attachmentIds setObject: [NSString stringWithFormat: @"%@%@%@",
                                                  [[self clientObject] baseURLInContext: [self context]],
                                                  thePartPath,
                                                  filename]
                                forKey: [NSString stringWithFormat: @"<%@>", filename]];
        }
    }
  else if ([thePart isKindOfClass: [NGMimeMultipartBody class]])
    {
      int i;

      for (i = 0; i < [[thePart parts] count]; i++)
        {
          [self _attachmentIdsFromBodyPart: [[thePart parts] objectAtIndex: i]
                                  partPath: [NSString stringWithFormat: @"%@%d/", thePartPath, i+1]];
        }
    }
}

- (id) contentViewerComponent
{
  id info;

  info = [self childInfo];
  return [[[self context] mailRenderingContext] viewerForBodyInfo: info];
}

- (id) renderedPart
{
  NSData *certificate, *decryptedData, *encryptedData;
  id info, viewer;

  certificate = [[[self clientObject] mailAccountFolder] certificate];
  encryptedData = [[self clientObject] content];
  decryptedData = [encryptedData decryptUsingCertificate: certificate];

  if (decryptedData)
    {
      NGMimeMessageParser *parser;
      id part;

      parser = [[NGMimeMessageParser alloc] init];
      part = [[parser parsePartFromData: decryptedData] retain];

      info = [NSDictionary dictionaryWithObjectsAndKeys: [[part contentType] type], @"type",
                           [[part contentType] subType], @"subtype", nil];
      viewer = [[[self context] mailRenderingContext] viewerForBodyInfo: info];
      [viewer setBodyInfo: info];
      [viewer setFlatContent: decryptedData];
      [viewer setDecodedContent: [part body]];

      // attachmentIds is empty in an ecrypted email as the IMAP body structure
      // is of course not available for file attachments
      [self _attachmentIdsFromBodyPart: [part body]  partPath: @""];
      [viewer setAttachmentIds: attachmentIds];

      return [NSDictionary dictionaryWithObjectsAndKeys:
                                 [self className], @"type",
                               [NSNumber numberWithBool: YES], @"valid",
                               [NSArray arrayWithObject: [viewer renderedPart]], @"content",
                           nil];
    }


  // Decryption failed, let's return something else...
  return [NSDictionary dictionaryWithObjectsAndKeys:
                         [self className], @"type",
                           [NSNumber numberWithBool: NO], @"valid",
                       [NSArray array], @"content",
                       nil];
}

@end /* UIxMailPartAlternativeViewer */
