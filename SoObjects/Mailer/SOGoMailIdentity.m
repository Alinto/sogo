/*
  Copyright (C) 2005 SKYRIX Software AG

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

#import <Foundation/NSString.h>

#import <NGExtensions/NSNull+misc.h>

#import "SOGoMailIdentity.h"

@implementation SOGoMailIdentity

- (void)dealloc {
  [name                release];
  [email               release];
  [replyTo             release];
  [organization        release];
  [signature           release];
  [vCard               release];
  [sentFolderName      release];
  [sentBCC             release];
  [draftsFolderName    release];
  [templatesFolderName release];
  [super dealloc];
}

/* accessors */

- (void)setName:(NSString *)_value {
  ASSIGNCOPY(name, _value);
}
- (NSString *)name {
  return name;
}

- (void)setEmail:(NSString *)_value {
  ASSIGNCOPY(email, _value);
}
- (NSString *)email {
  return email;
}

- (void)setReplyTo:(NSString *)_value {
  ASSIGNCOPY(replyTo, _value);
}
- (NSString *)replyTo {
  return replyTo;
}

- (void)setOrganization:(NSString *)_value {
  ASSIGNCOPY(organization, _value);
}
- (NSString *)organization {
  return organization;
}

- (void)setSignature:(NSString *)_value {
  ASSIGNCOPY(signature, _value);
}
- (NSString *)signature {
  return signature;
}
- (BOOL)hasSignature {
  return [[self signature] isNotEmpty];
}

- (void)setVCard:(NSString *)_value {
  ASSIGNCOPY(vCard, _value);
}
- (NSString *)vCard {
  return vCard;
}
- (BOOL)hasVCard {
  return [[self vCard] isNotEmpty];
}

- (void)setSentFolderName:(NSString *)_value {
  ASSIGNCOPY(sentFolderName, _value);
}
- (NSString *)sentFolderName {
  return sentFolderName;
}

- (void)setSentBCC:(NSString *)_value {
  ASSIGNCOPY(sentBCC, _value);
}
- (NSString *)sentBCC {
  return sentBCC;
}

- (void)setDraftsFolderName:(NSString *)_value {
  ASSIGNCOPY(draftsFolderName, _value);
}
- (NSString *)draftsFolderName {
  return draftsFolderName;
}

- (void)setTemplatesFolderName:(NSString *)_value {
  ASSIGNCOPY(templatesFolderName, _value);
}
- (NSString *)templatesFolderName {
  return templatesFolderName;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%08X[%@]:", self, NSStringFromClass([self class])];
  
  if (name  != nil) [ms appendFormat:@" name='%@'",  name];
  if (email != nil) [ms appendFormat:@" email='%@'", email];
  
  if (sentFolderName != nil) 
    [ms appendFormat:@" sent='%@'", sentFolderName];
  
  if ([sentBCC length] > 0) [ms appendString:@" sent-bcc"];
  if ([vCard length]   > 0) [ms appendString:@" vcard"];
  
  [ms appendString:@">"];
  return ms;
}

@end /* SOGoMailIdentity */
