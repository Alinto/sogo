/*
  Copyright (C) 2021 Inverse inc.

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
#import <Foundation/NSValue.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeHeaderFields.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeType.h>

#import <SoObjects/Mailer/NSString+Mail.h>
#import <SoObjects/Mailer/SOGoTNEFMailBodyPart.h>

#import "UIxMailRenderingContext.h"
#import "UIxMailPartTNEFViewer.h"

@implementation UIxMailPartTNEFViewer


- (void) _attachmentIdsFromBodyPart: (id) thePart
                           partPath: (NSString *) thePartPath
{
  if ([thePart isKindOfClass: [NGMimeBodyPart class]])
    {
      NSString *cid, *filename, *mimeType;

      mimeType = [[thePart contentType] stringValue];
      cid = [thePart contentId];
      filename = [(NGMimeContentDispositionHeaderField *)[thePart headerForKey: @"content-disposition"] filename];

      if (!filename)
        filename = [mimeType asPreferredFilenameUsingPath: nil];

      if (filename)
        {
          [(id)attachmentIds setObject: [NSString stringWithFormat: @"%@%@%@",
                                                  [[self clientObject] baseURLInContext: [self context]],
                                                  thePartPath,
                                                  filename]
                                forKey: [NSString stringWithFormat: @"<%@>", cid]];
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
  NSArray *parts;
  NSInteger i, max;
  NSMutableArray *renderedParts;
  SOGoTNEFMailBodyPart *tnefPart;
  id viewer, info;

  tnefPart = (SOGoTNEFMailBodyPart *)[self clientPart];
  parts = [[tnefPart bodyParts] parts];
  max = [parts count];
  renderedParts = [NSMutableArray arrayWithCapacity: max];

  // Populate the list of attachments ids
  for (i = 0; i < max; i++)
    {
      NGMimeBodyPart *part;

      part = [parts objectAtIndex: i];
      [self _attachmentIdsFromBodyPart: part
                              partPath: [NSString stringWithFormat: @"%@/%d/", [tnefPart bodyPartIdentifier], i+1]];
    }

  // Render each part
  for (i = 0; i < max; i++)
    {
      NGMimeBodyPart *part = [parts objectAtIndex: i];

      [self setChildIndex: i];
      [self setChildInfo: [part bodyInfo]];
      info = [self childInfo];

      viewer = [[[self context] mailRenderingContext] viewerForBodyInfo: info];
      [viewer setBodyInfo: info];
      [viewer setPartPath: [self childPartPath]];
      [viewer setAttachmentIds: attachmentIds];
      [viewer setFlatContent: [part body]];

      [renderedParts addObject: [viewer renderedPart]];
    }

  return [NSDictionary dictionaryWithObjectsAndKeys:
                         [self className], @"type",
                       renderedParts, @"content",
                       nil];
}

@end /* UIxMailPartTNEFViewer */
