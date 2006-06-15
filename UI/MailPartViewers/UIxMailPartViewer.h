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

#ifndef __Mailer_UIxMailPartViewer_H__
#define __Mailer_UIxMailPartViewer_H__

#include <SOGoUI/UIxComponent.h>

/*
  UIxMailPartViewer
  
  This class is the superclass for MIME content viewers.
  
  Since part-viewers can be reused for multiple parts, you need to be careful
  in subclass to properly reset your specific state by overriding
    - resetPathCaches

  The part viewers have access to the rendering state using the
    
    [[self context] mailRenderingContext]
    
  object. This class provides several convenience methods to access mailpart
  content.
*/

@class NSData, NSArray, NSFormatter;

@interface UIxMailPartViewer : UIxComponent
{
  NSArray *partPath;
  id      bodyInfo;
  NSData  *flatContent;
}

/* accessors */

- (void)setPartPath:(NSArray *)_path;
- (NSArray *)partPath;

- (void)setBodyInfo:(id)_info;
- (id)bodyInfo;

- (NSData *)flatContent;
- (NSData *)decodedFlatContent;
- (NSString *)flatContentAsString;

- (NSString *)preferredPathExtension;
- (NSString *)filename;
- (NSString *)filenameForDisplay;
- (NSFormatter *)sizeFormatter;

/* caches */

- (void)resetPathCaches;
- (void)resetBodyInfoCaches;

/* part URLs */

- (NSString *)pathToAttachmentObject; /* link to SoObject */
- (NSString *)pathToAttachment;       /* download link */

@end

#endif /* __Mailer_UIxMailPartViewer_H__ */
