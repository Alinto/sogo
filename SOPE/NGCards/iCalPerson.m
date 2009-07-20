/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSString.h>

#import "iCalPerson.h"

@implementation iCalPerson

/* accessors */

- (void) setCn: (NSString *) _s
{
  [self setValue: 0 ofAttribute: @"cn" to: _s];
}

- (NSString *) cn
{
  return [self value: 0 ofAttribute: @"cn"];
}

- (NSString *) cnWithoutQuotes
{
  /* remove quotes around a CN */
  NSString *_cn;
  
  _cn = [self cn];
  if ([_cn length] <= 2)
    return _cn;
  if ([_cn characterAtIndex:0] != '"')
    return _cn;
  if (![_cn hasSuffix:@"\""])
    return _cn;
  
  return [_cn substringWithRange:NSMakeRange(1, [_cn length] - 2)];
}

- (void) setEmail: (NSString *)_s
{
  // WARNING
  // don't touch unless you're going to re-test caldav sync 
  // with an iPhone AND lightning
  [self setValue: 0
        to: [NSString stringWithFormat: @"mailto:%@", _s]];
}

- (NSString *) email
{
  return [self value: 0];
}

- (NSString *) rfc822Email
{
  NSString *_email;
  unsigned idx;

  _email = [self email];
  idx    = NSMaxRange([_email rangeOfString:@":"]);

  if ((idx > 0) && ([_email length] > idx))
    return [_email substringFromIndex:idx];

  return _email;
}

- (void) setRsvp: (NSString *) _s
{
  [self setValue: 0 ofAttribute: @"rsvp" to: _s];
}

- (NSString *) rsvp
{
  return [[self value: 0 ofAttribute: @"rsvp"] lowercaseString];
}

// - (void)setXuid:(NSString *)_s {
//   ASSIGNCOPY(self->xuid, _s);
// }
// - (NSString *)xuid {
//   return self->xuid;
// }

- (void)setRole:(NSString *)_s
{
  [self setValue: 0 ofAttribute: @"role" to: _s];
}

- (NSString *) role
{
  return [self value: 0 ofAttribute: @"role"];
}

- (void)setPartStat:(NSString *)_s
{
  [self setValue: 0 ofAttribute: @"partstat" to: _s];
}

- (NSString *) partStat
{
  return [self value: 0 ofAttribute: @"partstat"];
}

- (NSString *) partStatWithDefault
{
  NSString *s;
  
  s = [self partStat];
  if ([s length] > 0)
    return s;
  
  return @"NEEDS-ACTION";
}

- (void) setParticipationStatus: (iCalPersonPartStat) _status
{
  NSString *stat;

  switch (_status) {
    case iCalPersonPartStatAccepted:
      stat = @"ACCEPTED";
      break;
    case iCalPersonPartStatDeclined:
      stat = @"DECLINED";
      break;
    case iCalPersonPartStatTentative:
      stat = @"TENTATIVE";
      break;
    case iCalPersonPartStatDelegated:
      stat = @"DELEGATED";
      break;
    case iCalPersonPartStatCompleted:
      stat = @"COMPLETED";
      break;
    case iCalPersonPartStatInProcess:
      stat = @"IN-PROCESS";
      break;
    case iCalPersonPartStatExperimental:
    case iCalPersonPartStatOther:
//       [NSException raise:NSInternalInconsistencyException
//                    format:@"Attempt to set meaningless "
//                           @"participationStatus (%d)!", _status];
      stat = nil; /* keep compiler happy */
      break;
    default:
      stat = @"NEEDS-ACTION";
      break;
  }
  if (stat)
    [self setPartStat:stat];
}

- (iCalPersonPartStat)participationStatus {
  NSString *stat;
  
  stat = [[self partStat] uppercaseString];
  if (![stat length] || [stat isEqualToString:@"NEEDS-ACTION"])
    return iCalPersonPartStatNeedsAction;
  else if ([stat isEqualToString:@"ACCEPTED"])
    return iCalPersonPartStatAccepted;
  else if ([stat isEqualToString:@"DECLINED"])
    return iCalPersonPartStatDeclined;
  else if ([stat isEqualToString:@"TENTATIVE"])
    return iCalPersonPartStatTentative;
  else if ([stat isEqualToString:@"DELEGATED"])
    return iCalPersonPartStatDelegated;
  else if ([stat isEqualToString:@"COMPLETED"])
    return iCalPersonPartStatCompleted;
  else if ([stat isEqualToString:@"IN-PROCESS"])
    return iCalPersonPartStatInProcess;
  else if ([stat hasPrefix:@"X-"])
    return iCalPersonPartStatExperimental;
  return iCalPersonPartStatOther;
}


/* comparison */

- (unsigned)hash {
  if([self email])
    return [[self email] hash];
  return [super hash];
}

- (BOOL)isEqual:(id)_other {
  if(_other == nil)
    return NO;
  if([_other class] != self->isa)
    return NO;
  if([_other hash] != [self hash])
    return NO;
  return [self isEqualToPerson:_other];
}

- (BOOL)isEqualToPerson:(iCalPerson *)_other {
  if(![self hasSameEmailAddress:_other])
    return NO;
  if(!IS_EQUAL([self cn], [_other cn], isEqualToString:))
    return NO;
  if(!IS_EQUAL([self rsvp], [_other rsvp], isEqualToString:))
    return NO;
  if(!IS_EQUAL([self partStat], [_other partStat], isEqualToString:))
    return NO;
  if(!IS_EQUAL([self role], [_other role], isEqualToString:))
    return NO;
//   if(!IS_EQUAL([self xuid], [_other xuid], isEqualToString:))
//     return NO;
  return YES;
}

- (BOOL)hasSameEmailAddress:(iCalPerson *)_other {
  return IS_EQUAL([[self email] lowercaseString],
                  [[_other email] lowercaseString],
                  isEqualToString:);
}

@end /* iCalPerson */
