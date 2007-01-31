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

#include "iCalDateHolder.h"
#include "iCalObject.h"
#include "common.h"

@interface NSTimeZone(iCalTimeZone)

+ (NSTimeZone *)timeZoneWithICalId:(NSString *)_tz;

@end

@implementation iCalDateHolder

static NSTimeZone *gmt = nil;

+ (void)initialize {
  if (gmt == nil)
    gmt = [[NSTimeZone timeZoneWithName:@"GMT"] retain];
}

- (void)dealloc {
  [self->tzid   release];
  [self->string release];
  [self->tag    release];
  [super dealloc];
}

/* accessors */

- (void)setString:(NSString *)_value {
  ASSIGNCOPY(self->string, _value);
}
- (NSString *)string {
  return self->string;
}

- (void)setTag:(NSString *)_value {
  ASSIGNCOPY(self->tag, _value);
}
- (NSString *)tag {
  return self->tag;
}

- (void)setTzid:(NSString *)_value {
  ASSIGNCOPY(self->tzid, _value);
}
- (NSString *)tzid {
  return self->tzid;
}

/* mapping to Foundation */

- (NSTimeZone *)timeZone {
  // TODO: lookup tzid in iCalCalendar !
  NSString *s;

  s = [self tzid];
  
  /* a hack */
  if ([s hasPrefix:@"/softwarestudio.org"]) {
    NSRange r;
    
    r = [s rangeOfString:@"Europe/"];
    if (r.length > 0)
      s = [s substringFromIndex:r.location];
  }
  return [NSTimeZone timeZoneWithICalId:s];
}

/* decoding */

- (id)awakeAfterUsingSaxDecoder:(id)_decoder {
  NSCalendarDate *date = nil;
  NSString   *s;
  NSTimeZone *tz;
  
  s = self->string;
  if ([s length] < 5) {
    [self logWithFormat:@"tag %@: got an weird date string '%@' ?!", 
	    self->tag, s];
    return s;
  }
  
  /* calculate timezone */
  
  if ([self->string hasSuffix:@"Z"]) {
    /* zulu time, eg 20021009T094500Z */
    tz = gmt;
    s = [s substringToIndex:([s length] - 1)];
  }
  else
    tz = [self timeZone];
  
  /* 
     012345678901234
     20021009T094500 - 15 chars 
     20021009T0945   - 13 chars 
     991009T0945     - 11 chars
     
     20031111        - 8 chars
  */
  if ([s rangeOfString:@"T"].length == 0 && [s length] == 8) {
    /* hm, maybe a date without a time? like an allday event! */
    int year, month, day;
    char buf[16];
    [s getCString:&(buf[0])];
    
    buf[9] = '\0';
    day    = atoi(&(buf[6]));  buf[6] = '\0';
    month  = atoi(&(buf[4]));  buf[4] = '\0';
    year   = atoi(&(buf[0]));
    
    date = [NSCalendarDate dateWithYear:year month:month day:day
                           hour:0 minute:0 second:0
                           timeZone:tz];
  }
  else if ([s length] == 15) {
    int year, month, day, hour, minute, second;
    char buf[24];
    [s getCString:&(buf[0])];
      
    second = atoi(&(buf[13])); buf[13] = '\0';
    minute = atoi(&(buf[11])); buf[11] = '\0';
    hour   = atoi(&(buf[9]));  buf[9] = '\0';
    day    = atoi(&(buf[6]));  buf[6] = '\0';
    month  = atoi(&(buf[4]));  buf[4] = '\0';
    year   = atoi(&(buf[0]));
      
    date = [NSCalendarDate dateWithYear:year month:month day:day
                           hour:hour minute:minute second:second
                           timeZone:tz];
  }
  else
    NSLog(@"%s: unknown date format (%@) ???", __PRETTY_FUNCTION__, s);
    
  if (date == nil)
    NSLog(@"couldn't convert string '%@' to date (format '%@') ..", s);

  return date;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)ms {
  if (self->tag)    [ms appendFormat:@" %@",  self->tag];
  if (self->string) [ms appendFormat:@" '%@'",  self->string];
  if (self->tzid)   [ms appendFormat:@" tz=%@", self->tzid];
}

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:ms];
  [ms appendString:@">"];
  return ms;
}

@end /* iCalDateHolder */

@implementation NSTimeZone(iCalTimeZone)

static NSMutableDictionary *idToTz = nil; // THREAD

+ (NSTimeZone *)timeZoneWithICalId:(NSString *)_tzid {
  static NSString *iCalDefaultTZ = nil;
  NSTimeZone *tz;
  
  if (idToTz == nil)
    idToTz = [[NSMutableDictionary alloc] initWithCapacity:16];
  
  if ([_tzid length] == 0) {
    
    tz = [iCalObject iCalDefaultTimeZone];
    if (tz != nil) return tz;

    if (iCalDefaultTZ == nil) {
      NSString *defTz;
      NSUserDefaults *ud;
      // TODO: take a default timeZone
      ud = [NSUserDefaults standardUserDefaults];
      defTz = [ud stringForKey:@"iCalTimeZoneName"];
      if ([defTz length] == 0)
        defTz = [ud stringForKey:@"TimeZoneName"];
      if ([defTz length] == 0)
        defTz = [ud stringForKey:@"TimeZone"];
      if ([defTz length] == 0)
        defTz = @"GMT";
      iCalDefaultTZ = [defTz retain];
    }
    
    _tzid = iCalDefaultTZ;
    
  }
  
  if ([_tzid length] == 0)
    _tzid = @"GMT";
  
  tz = [idToTz objectForKey:_tzid];
  if (tz == nil) tz = [NSTimeZone timeZoneWithName:_tzid];
  if (tz == nil) tz = [NSTimeZone timeZoneWithAbbreviation:_tzid];
  
  if (tz == nil) {
    NSLog(@"couldn't map timezone id %@", _tzid);
  }
  
  if (tz) [idToTz setObject:tz forKey:_tzid];
  return tz;
}

@end /* NSTimeZone(iCalTimeZone) */
