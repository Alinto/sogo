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

#include "UIxMailFormatter.h"
#include "common.h"

#include <NGMail/NGMimeMessageParser.h>

@implementation UIxSubjectFormatter

static Class StrClass  = Nil;
static Class DataClass = Nil;

+ (void)initialize {
  StrClass  = [NSString class];
  DataClass = [NSData   class];
}

- (id)init {
  if ((self = [super init])) {
    self->maxLength = 64;
  }
  return self;
}

/* configuration */

- (unsigned int)maxLength {
  return self->maxLength;
}

- (BOOL)shouldDecodeQP {
  return YES;
}

/* labels */

- (NSString *)missingSubjectLabel {
  return [self labelForKey:@"no_subject"];
}

/* specific formatters */

- (NSString *)stringForStringValue:(NSString *)_subject {
  NSString *s;
  
  /* quoted printable */
  if ([self shouldDecodeQP] && [_subject hasPrefix:@"=?"]) {
    /* 
       Now this is interesting. An NSString should not contain QP markers since
       it is already 'charset decoded'. This is also why the NGMime parser
       expects an NSData.
       
       Sample:
         =?iso-8859-1?q?Yannick=20DAmboise?=

       Note: -stringByDecodingQuotedPrintable only expands =D0 like charcodes!
    */
    NSData *data;
    
    /* header field data should always be ASCII */
    data = [_subject dataUsingEncoding:NSUTF8StringEncoding];
    return [self stringForDataValue:data];
  }
  
  if ([_subject length] == 0)
    return [self missingSubjectLabel];
  
  if ([_subject length] <= [self maxLength])
    return _subject;
  
  s = [_subject substringToIndex:([self maxLength] - 3)];
  return [s stringByAppendingString:@"..."];
}

- (NSString *)stringForDataValue:(NSData *)_subject {
  NSString *s, *r;
  unsigned len;
  
  if ((len = [_subject length]) == 0)
    return [self missingSubjectLabel];
  
  /* check for quoted printable */
  
  if (len > 6 && [self shouldDecodeQP]) {
    const unsigned char *b;
    
    b = [_subject bytes];
    if (b[0] == '=' && b[1] == '?') {
      /* eg: '=?iso-8859-1?q?Yannick=20DAmboise?=' */
      id t;
      
      t = [_subject decodeQuotedPrintableValueOfMIMEHeaderField:@"subject"];
      if ([t isNotNull])
	return [self stringForObjectValue:t];
      else
	[self warnWithFormat:@"decoding QP failed: '%@'", t];
    }
  }
  
  /* continue NSData processing */
  
  [self warnWithFormat:@"NSData subject, using UTF-8 to decode."];
  
  // TODO: exception handler?
  s = [[NSString alloc] initWithData:_subject encoding:NSUTF8StringEncoding];
  if (s == nil) {
    [self errorWithFormat:@"could do not decode NSData subject!"];
    return [self labelForKey:@"Error_CouldNotDecodeSubject"];
  }
  
  if ([s hasPrefix:@"=?"]) { // TODO: this should never happen?
    [self warnWithFormat:@"subject still has QP signature: '%@'", s];
    r = [s copy];
  }
  else
    r = [[self stringForStringValue:s] copy];
  [s release];
  return [r autorelease];
}

/* formatter entry function */

- (NSString *)stringForObjectValue:(id)_subject {
  if (![_subject isNotNull])
    return [self missingSubjectLabel];
  
  if ([_subject isKindOfClass:StrClass])
    return [self stringForStringValue:_subject];
  if ([_subject isKindOfClass:DataClass])
    return [self stringForDataValue:_subject];
  
  return [self stringForStringValue:[_subject stringValue]];
}

@end /* UIxSubjectFormatter */
