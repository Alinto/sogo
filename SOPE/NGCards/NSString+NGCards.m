/* NSString+NGCards.m - this file is part of SOPE
 *
 * Copyright (C) 2006-2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSRange.h>
#import <Foundation/NSTimeZone.h>

#import <NGExtensions/NSObject+Logs.h>

#import <ctype.h>

#import "NSString+NGCards.h"

@implementation NSString (NGCardsExtensions)

- (NSString *) foldedForVersitCards
{
  NSMutableString *foldedString;
  unsigned int length;
  NSRange subStringRange;

  foldedString = [NSMutableString string];

  length = [self length];
  if (length < 77)
    [foldedString appendString: self];
  else
    {
      subStringRange = NSMakeRange (0, 75);
      [foldedString appendFormat: @"%@\r\n",
                    [self substringWithRange: subStringRange]];
      subStringRange = NSMakeRange (75, 74);
      while ((length - subStringRange.location) > 75)
        {
          [foldedString appendFormat: @" %@\r\n",
                        [self substringWithRange: subStringRange]];
          subStringRange.location += 74;
        }
      subStringRange.length = length - subStringRange.location;
      [foldedString appendFormat: @" %@",
                    [self substringWithRange: subStringRange]];
    }

  return foldedString;
}

- (NSArray *) asCardAttributeValues
{
  NSMutableArray *values;
  NSString *newString;
  unichar *characters, *currentChar, *lastChar, *newPart, *newCurrentChar;
  NSUInteger max;
  BOOL isEscaped, isQuoted;

  values = [NSMutableArray array];

  max = [self length];
  characters = NSZoneMalloc (NULL, max * sizeof (unichar));
  [self getCharacters: characters];
  currentChar = characters;
  lastChar = characters + max;

  newPart = NSZoneMalloc (NULL, max * sizeof (unichar));
  newCurrentChar = newPart;

  isEscaped = NO;
  isQuoted = NO;

  while (currentChar < lastChar)
    {
      if (isQuoted)
        {
          if (*currentChar == '"')
            isQuoted = NO;
          else
            {
              *newCurrentChar = *currentChar;
              newCurrentChar++;
            }
        }
      else if (isEscaped)
        {
          if (*currentChar == 'n' || *currentChar == 'N')
            *newCurrentChar = '\n';
          else if (*currentChar == 'r' || *currentChar == 'R')
            *newCurrentChar = '\r';
          else if (*currentChar == 't' || *currentChar == 'T')
            *newCurrentChar = '\t';
          else if (*currentChar == 'b' || *currentChar == 'B')
            *newCurrentChar = '\b';
          else
            *newCurrentChar = *currentChar;
          newCurrentChar++;
          isEscaped = NO;
        }
      else
        {
          if (*currentChar == '"')
            isQuoted = YES;
          else if (*currentChar == '\\')
            isEscaped = YES;
          else if (*currentChar == ',')
            {
              newString = [[NSString alloc]
                            initWithCharactersNoCopy: newPart
                                              length: (newCurrentChar - newPart)
                                        freeWhenDone: YES];
              [values addObject: newString];
              [newString release];
              newPart = NSZoneMalloc (NULL, max * sizeof (unichar));
              newCurrentChar = newPart;
            }
          else
            {
              *newCurrentChar = *currentChar;
              newCurrentChar++;
            }
        }
      currentChar++;
    }

  newString = [[NSString alloc]
                initWithCharactersNoCopy: newPart
                                  length: (newCurrentChar - newPart)
                            freeWhenDone: YES];
  [values addObject: newString];
  [newString release];

  NSZoneFree (NULL, characters);

  return values;
}

- (NSString *) escapedForCards
{
  NSString *string;

  string = [self stringByReplacingString: @"\\"
                 withString: @"\\\\"];
  string = [string stringByReplacingString: @","
                   withString: @"\\,"];
  //  string = [string stringByReplacingString: @":"
  //                withString: @"\\:"];
  string = [string stringByReplacingString: @";"
                   withString: @"\\;"];
  string = [string stringByReplacingString: @"\n"
                   withString: @"\\n"];
  string = [string stringByReplacingString: @"\r"
                   withString: @"\\r"];

  return string;
}

- (NSTimeInterval) durationAsTimeInterval
{
  /*
    eg: DURATION:PT1H
    P      - "period"
    P2H30M - "2 hours 30 minutes"

     dur-value  = (["+"] / "-") "P" (dur-date / dur-time / dur-week)

     dur-date   = dur-day [dur-time]
     dur-time   = "T" (dur-hour / dur-minute / dur-second)
     dur-week   = 1*DIGIT "W"
     dur-hour   = 1*DIGIT "H" [dur-minute]
     dur-minute = 1*DIGIT "M" [dur-second]
     dur-second = 1*DIGIT "S"
     dur-day    = 1*DIGIT "D"
  */
  unsigned       i, len;
  NSTimeInterval ti;
  BOOL           isNegative;
  int            val;
  unichar c;
  
  ti  = 0.0;
  i = 0;

  c = [self characterAtIndex: i];
  if (c == '-')
    {
      isNegative = YES;
      i++;
    }
  else
    {
      isNegative = NO;
    }
  
  c = [self characterAtIndex: i];
  if (c == 'P')
    {
      val = 0;

      len = [self length];

      for (i++; i < len; i++)
	{
	  c = [self characterAtIndex: i];
	  if (c == 't' || c == 'T')
	    {
	      val = 0;
	    }
	  else if (isdigit (c))
	    val = (val * 10) + (c - 48);
	  else
	    {
	      switch (c)
		{
		case 'W': /* week */
		  ti += (val * 7 * 24 * 60 * 60);
		  break;
		case 'D': /* day  */
		  ti += (val * 24 * 60 * 60);
		  break;
		case 'H': /* hour */
		  ti += (val * 60 * 60);
		  break;
		case 'M': /* min  */
		  ti += (val * 60);
		  break;
		case 'S': /* sec  */
		  ti += val;
		  break;
		default:
		  [self logWithFormat: @"cannot process duration unit: '%c'", c];
		  break;
		}

	      val = 0;
	    }
	}
    }
  else
    NSLog(@"Cannot parse iCal duration value: '%@'", self);

  if (isNegative)
    ti = -ti;
  
  return ti;
}

- (NSCalendarDate *) asCalendarDate
{
  NSRange cursor;
  NSCalendarDate *date;
  NSTimeZone *utc;
  unsigned int length;
  int year, month, day, hour, minute, second;

  length = [self length];
  if (length > 7)
    {
      cursor = NSMakeRange(0, 4);
      year = [[self substringWithRange: cursor] intValue];
      cursor.location += cursor.length;
      cursor.length = 2;
      if ([[self substringWithRange: cursor] hasPrefix: @"-"])
	cursor.location += 1;
      month = [[self substringWithRange: cursor] intValue];
      cursor.location += cursor.length;
      if ([[self substringWithRange: cursor] hasPrefix: @"-"])
	cursor.location += 1;
      day = [[self substringWithRange: cursor] intValue];

      if (length > 14)
	{
	  cursor.location += cursor.length + 1;
	  hour = [[self substringWithRange: cursor] intValue];
	  cursor.location += cursor.length;
	  minute = [[self substringWithRange: cursor] intValue];
	  cursor.location += cursor.length;
	  second = [[self substringWithRange: cursor] intValue];
	}
      else
	{
	  hour = 0;
	  minute = 0;
	  second = 0;
	}

      utc = [NSTimeZone timeZoneWithAbbreviation: @"GMT"];
      date = [NSCalendarDate dateWithYear: year month: month 
                             day: day hour: hour minute: minute 
                             second: second
                             timeZone: utc];
    }
  else
    date = nil;

  return date;
}

- (BOOL) isAllDayDate
{
  return ([self length] == 8);
}

- (NSMutableDictionary *) vCardSubvalues
{
  /* This schema enables things like this:
     ELEM;...:KEY1=subvalue1;KEY2=subvalue1,subvalue2
     or
     ELEM;...:subvalue1;subvalue1,subvalue2 (where KEY = @"") */
  NSMutableDictionary *values; /* key <> ordered values associations */
  NSMutableArray *orderedValues = nil; /* those are separated by ';' and contain
                                          subvalues, may or may not be named */
  NSMutableArray *subValues = nil; /* those are separeted by ',' */
  unichar *stringBuffer, *substringBuffer;
  NSString *valuesKey, *substring;
  unichar currentChar;
  NSUInteger substringLength, count, max;
  BOOL escaped = NO;

  values = [NSMutableDictionary dictionary];
  valuesKey = @"";

  max = [self length];
  stringBuffer = NSZoneMalloc (NULL, sizeof (unichar) * (max + 1));
  [self getCharacters: stringBuffer];
  stringBuffer[max] = 0;

  substringBuffer = NSZoneMalloc (NULL, sizeof (unichar) * max);
  substringLength = 0;

  max += 1; /* we add one step to force the inclusion of the ending '\0' in
               the loop */
  for (count = 0; count < max; count++)
    {
      currentChar = stringBuffer[count];
      if (escaped)
        {
          escaped = NO;
          if (currentChar == 'n' || currentChar == 'N')
            substringBuffer[substringLength] = '\n';
          else if (currentChar == 'r' || currentChar == 'R')
            substringBuffer[substringLength] = '\r';
          else
            substringBuffer[substringLength] = currentChar;
          substringLength++;
        }
      else
        {
          if (currentChar == '\\')
            escaped = YES;
          else if (currentChar == ',' || currentChar == ';' || currentChar == 0)
            {
              substring
                = [[NSString alloc] initWithCharacters: substringBuffer
                                                length: substringLength];
              substringLength = 0;

              orderedValues = [values objectForKey: valuesKey];
              if (!orderedValues)
                {
                  orderedValues = [NSMutableArray new];
                  [values setObject: orderedValues forKey: valuesKey];
                  [orderedValues release];
                }
              if (!subValues)
                {
                  subValues = [NSMutableArray new];
                  [orderedValues addObject: subValues];
                  [subValues release];
                }
              if ([substring length] > 0)
                [subValues addObject: substring];
              [substring release];

              if (currentChar != ',')
                {
                  orderedValues = nil;
                  subValues = nil;
                  valuesKey = @"";
                }
            }
          /* hack: 16 chars is an arbitrary limit to distinguish between
             "named properties" and the base64 padding character. This might
             need further tweaking... */
          else if (currentChar == '=' && substringLength < 16)
            {
              substring
                = [[NSString alloc] initWithCharacters: substringBuffer
                                                length: substringLength];
              [substring autorelease];
              substringLength = 0;
              valuesKey = [substring lowercaseString];
            }
          else
            {
              substringBuffer[substringLength] = currentChar;
              substringLength++;
            }
        }
    }

  NSZoneFree (NULL, stringBuffer);
  NSZoneFree (NULL, substringBuffer);

  return values;
}

- (NSString *) rfc822Email
{
  unsigned idx;

  idx = NSMaxRange([self rangeOfString:@":"]);

  if ((idx > 0) && ([self length] > idx))
    return [self substringFromIndex: idx];

  return self;
}


@end
