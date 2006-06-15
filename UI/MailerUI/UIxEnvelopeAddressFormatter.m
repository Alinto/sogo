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
#include <NGImap4/NGImap4EnvelopeAddress.h>
#include "common.h"

@implementation UIxEnvelopeAddressFormatter

static Class EnvAddrClass = Nil;
static Class StrClass     = Nil;

+ (void)initialize {
  EnvAddrClass = [NGImap4EnvelopeAddress class];
  StrClass     = [NSString       class];
}

- (id)initWithMaxLength:(unsigned int)_max generateFullEMail:(BOOL)_genFull {
  if ((self = [super init])) {
    self->maxLength = _max;
    self->separator = @", ";
    
    self->eafFlags.fullEMail = _genFull ? 1 : 0;
  }
  return self;
}
- (id)init {
  return [self initWithMaxLength:128 generateFullEMail:NO];
}

/* configuration */

- (unsigned)maxLength {
  return self->maxLength;
}
- (NSString *)separator {
  return self->separator;
}
- (BOOL)generateFullEMail {
  return self->eafFlags.fullEMail ? YES : NO;
}

/* formatting envelope addresses */

- (NSString *)stringForEnvelopeAddress:(NGImap4EnvelopeAddress *)_address {
  NSString *s;

  if ([self generateFullEMail])
    return [_address email];
  
  s = [_address personalName];
  if ([s isNotNull]) return s;
  
  s = [_address baseEMail];
  if ([s isNotNull]) return s;
  
  [self warnWithFormat:@"unexpected envelope address: %@", _address];
  return [_address stringValue];
}

- (NSString *)stringForArray:(NSArray *)_addresses {
  NSMutableString *ms;
  unsigned i, count;
  
  if ((count = [_addresses count]) == 0)
    return nil;
  
  if (count == 1)
    return [self stringForObjectValue:[_addresses objectAtIndex:0]];
  
  ms = [NSMutableString stringWithCapacity:16 * count];
  for (i = 0; i < count && [ms length] < [self maxLength]; i++) {
    NSString *s;
    
    s = [self stringForObjectValue:[_addresses objectAtIndex:i]];
    if (s == nil)
      continue;
    
    if ([ms length] > 0) [ms appendString:[self separator]];
    [ms appendString:s];
  }
  return ms;
}

/* formatter entry function */

- (NSString *)stringForObjectValue:(id)_address {
  if (![_address isNotNull])
    return nil;
  
  if ([_address isKindOfClass:StrClass]) /* preformatted? */
    return _address;
  
  if ([_address isKindOfClass:EnvAddrClass])
    return [self stringForEnvelopeAddress:_address];
  
  if ([_address isKindOfClass:[NSArray class]])
    return [self stringForArray:_address];

  [self debugWithFormat:
	  @"NOTE: unexpected object for envelope formatter: %@<%@>",
	  _address, NSStringFromClass([_address class])];
  return [_address stringValue];
}

@end /* UIxEnvelopeAddressFormatter */
