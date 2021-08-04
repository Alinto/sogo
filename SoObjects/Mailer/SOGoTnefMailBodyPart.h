/*
  Copyright (C) 2005-2017 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#ifndef __Mailer_SOGoTnefMailBodyPart_H__
#define __Mailer_SOGoTnefMailBodyPart_H__

#import "SOGoMailBodyPart.h"

@class NGMimeBodyPart;

@interface SOGoTnefMailBodyPart : SOGoMailBodyPart
{
  NSData *part;
  NSString *filename;
  NGMimeMultipartBody *bodyParts;
}

- (NGMimeMultipartBody *) bodyParts;
- (void) setFilename: (NSString *) newFilename;
- (void) setPart: (NGMimeBodyPart *) newPart;
- (void) setPartInfo: (id) newPartInfo;
- (void) decodeBLOB;
- (NGMimeBodyPart *) bodyPartForData: (NSData *)   _data
                            withType: (NSString *) _type
                          andSubtype: (NSString *) _subtype;
- (NGMimeBodyPart *) bodyPartForAttachment: (NSData *)   _data
                                  withName: (NSString *) _name
                                   andType: (NSString *) _type
                                andSubtype: (NSString *) _subtype
                              andContentId: (NSString *) _cid;

@end

#endif /* __Mailer_SOGoTnefMailBodyPart_H__ */
