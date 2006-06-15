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

#include <SOGoUI/UIxComponent.h>

/*
  UIxMailEditorAction
  
  An mail editor component which works on SOGoDraftObject's. This component
  manages the attachments of a draft object.
*/

@class NSArray, NSString, NSData;

@interface UIxMailEditorAttach : UIxComponent
{
  NSString *filePath1;
  NSString *filePath2;
  NSString *filePath3;
  NSData   *fileData1;
  NSData   *fileData2;
  NSData   *fileData3;
  NSString *attachmentName;

  NSArray *attachmentNames;
}

@end

#include <SoObjects/Mailer/SOGoDraftObject.h>
#include "common.h"

@implementation UIxMailEditorAttach

- (void)dealloc {
  [self->attachmentNames release];
  [self->attachmentName release];
  [self->filePath1 release];
  [self->filePath2 release];
  [self->filePath3 release];
  [self->fileData1 release];
  [self->fileData2 release];
  [self->fileData3 release];
  [super dealloc];
}

/* accessors */

- (void)setAttachmentName:(NSString *)_value {
  ASSIGNCOPY(self->attachmentName, _value);
}
- (NSString *)attachmentName {
  return self->attachmentName;
}

- (void)setFilePath1:(NSString *)_value {
  ASSIGNCOPY(self->filePath1, _value);
}
- (NSString *)filePath1 {
  return self->filePath1;
}

- (void)setFilePath2:(NSString *)_value {
  ASSIGNCOPY(self->filePath2, _value);
}
- (NSString *)filePath2 {
  return self->filePath2;
}

- (void)setFilePath3:(NSString *)_value {
  ASSIGNCOPY(self->filePath3, _value);
}
- (NSString *)filePath3 {
  return self->filePath3;
}

- (void)setFileData1:(NSData *)_data {
  ASSIGN(self->fileData1, _data);
}
- (NSData *)fileData1 {
  return self->fileData1;
}

- (void)setFileData2:(NSData *)_data {
  ASSIGN(self->fileData2, _data);
}
- (NSData *)fileData2 {
  return self->fileData2;
}

- (void)setFileData3:(NSData *)_data {
  ASSIGN(self->fileData3, _data);
}
- (NSData *)fileData3 {
  return self->fileData3;
}

- (NSArray *)attachmentNames {
  NSArray *a;

  if (self->attachmentNames != nil)
    return self->attachmentNames;
  
  a = [[self clientObject] fetchAttachmentNames];
  a = [a sortedArrayUsingSelector:@selector(compare:)];
  self->attachmentNames = [a copy];
  return self->attachmentNames;
}
- (BOOL)hasAttachments {
  return [[self attachmentNames] count] > 0 ? YES : NO;
}

/* requests */

- (BOOL)shouldTakeValuesFromRequest:(WORequest *)_rq inContext:(WOContext*)_c{
  return YES;
}

/* operations */

- (NSString *)defaultPathExtension {
  return @"txt";
}

- (NSString *)newAttachmentName {
  NSArray  *usedNames;
  unsigned i;
  
  usedNames = [[self clientObject] fetchAttachmentNames];
  for (i = [usedNames count]; i < 100; i++) {
    NSString *name;
    
    name = [NSString stringWithFormat:@"attachment%d", i];
    if (![usedNames containsObject:name])
      return name;
  }
  [self errorWithFormat:@"too many attachments?!"];
  return nil;
}

- (NSString *)fixupAttachmentName:(NSString *)_name {
  NSString *pe;
  NSRange r;

  if (_name == nil)
    return  nil;
  
  pe = [_name pathExtension];
  if ([pe length] == 0)
    /* would be better to check the content-type, but well */
    pe = [self defaultPathExtension];
  
  r = [_name rangeOfString:@"/"];
  if (r.length > 0) _name = [_name lastPathComponent];
  
  r = [_name rangeOfString:@" "];
  if (r.length > 0) 
    _name = [_name stringByReplacingString:@" " withString:@"_"];
  
  if ([_name hasPrefix:@"."]) {
    _name = [@"dotfile-" stringByAppendingString:
		[_name substringFromIndex:1]];
  }
  
  // TODO: should we need to check for umlauts?
  
  if ([_name length] == 0)
    return [[self newAttachmentName] stringByAppendingPathExtension:pe];
  
  return _name;
}

- (BOOL)saveFileData:(NSData *)_data name:(NSString *)_name {
  NSException *error;
  
  if (_data == nil)
    return NO;
  if ([_name length] == 0) {
    _name = [self newAttachmentName];
    _name = [_name stringByAppendingPathExtension:[self defaultPathExtension]];
  }
  
  if ((_name = [self fixupAttachmentName:_name]) == nil)
    return NO;
  
  // TODO: add size limit?
  error = [[self clientObject] saveAttachment:_data withName:_name];
  if (error != nil) {
    [self logWithFormat:@"ERROR: could not save: %@", error];
    return NO;
  }
  return YES;
}

/* actions */

- (id)viewAttachmentsAction {
  [self debugWithFormat:@"view attachments ..."];
  return self;
}

- (id)attachAction {
  BOOL ok;
  
  ok = YES;
  if ([self->fileData1 length] > 0)
    ok = [self saveFileData:self->fileData1 name:[self filePath1]];
  if (ok && [self->fileData2 length] > 0)
    ok = [self saveFileData:self->fileData2 name:[self filePath2]];
  if (ok && [self->fileData3 length] > 0)
    [self saveFileData:self->fileData3 name:[self filePath3]];
  
  if (!ok) {
    // TODO: improve error handling
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"failed to save attachment ..."];
  }
  
  return [self redirectToLocation:@"viewAttachments"];
}

- (id)deleteAttachmentAction {
  NSException *error;

  error = [[self clientObject] deleteAttachmentWithName:[self attachmentName]];
  
  if (error != nil)
    return error;
  
  return [self redirectToLocation:@"viewAttachments"];
}

@end /* UIxMailEditorAttach */
