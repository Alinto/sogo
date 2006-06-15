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

#include "SOGoMailIdentity.h"
#include "common.h"

@implementation SOGoMailIdentity

- (void)dealloc {
  [self->name                release];
  [self->email               release];
  [self->replyTo             release];
  [self->organization        release];
  [self->signature           release];
  [self->vCard               release];
  [self->sentFolderName      release];
  [self->sentBCC             release];
  [self->draftsFolderName    release];
  [self->templatesFolderName release];
  [super dealloc];
}

/* accessors */

- (void)setName:(NSString *)_value {
  ASSIGNCOPY(self->name, _value);
}
- (NSString *)name {
  return self->name;
}

- (void)setEmail:(NSString *)_value {
  ASSIGNCOPY(self->email, _value);
}
- (NSString *)email {
  return self->email;
}

- (void)setReplyTo:(NSString *)_value {
  ASSIGNCOPY(self->replyTo, _value);
}
- (NSString *)replyTo {
  return self->replyTo;
}

- (void)setOrganization:(NSString *)_value {
  ASSIGNCOPY(self->organization, _value);
}
- (NSString *)organization {
  return self->organization;
}

- (void)setSignature:(NSString *)_value {
  ASSIGNCOPY(self->signature, _value);
}
- (NSString *)signature {
  return self->signature;
}
- (BOOL)hasSignature {
  return [[self signature] isNotEmpty];
}

- (void)setVCard:(NSString *)_value {
  ASSIGNCOPY(self->vCard, _value);
}
- (NSString *)vCard {
  return self->vCard;
}
- (BOOL)hasVCard {
  return [[self vCard] isNotEmpty];
}

- (void)setSentFolderName:(NSString *)_value {
  ASSIGNCOPY(self->sentFolderName, _value);
}
- (NSString *)sentFolderName {
  return self->sentFolderName;
}

- (void)setSentBCC:(NSString *)_value {
  ASSIGNCOPY(self->sentBCC, _value);
}
- (NSString *)sentBCC {
  return self->sentBCC;
}

- (void)setDraftsFolderName:(NSString *)_value {
  ASSIGNCOPY(self->draftsFolderName, _value);
}
- (NSString *)draftsFolderName {
  return self->draftsFolderName;
}

- (void)setTemplatesFolderName:(NSString *)_value {
  ASSIGNCOPY(self->templatesFolderName, _value);
}
- (NSString *)templatesFolderName {
  return self->templatesFolderName;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%08X[%@]:", self, NSStringFromClass([self class])];
  
  if (self->name  != nil) [ms appendFormat:@" name='%@'",  self->name];
  if (self->email != nil) [ms appendFormat:@" email='%@'", self->email];
  
  if (self->sentFolderName != nil) 
    [ms appendFormat:@" sent='%@'", self->sentFolderName];
  
  if ([self->sentBCC length] > 0) [ms appendString:@" sent-bcc"];
  if ([self->vCard length]   > 0) [ms appendString:@" vcard"];
  
  [ms appendString:@">"];
  return ms;
}

@end /* SOGoMailIdentity */
