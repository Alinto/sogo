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

/*
  UIxMailPartTextViewer

  Show plaintext mail parts correctly formatted.

  TODO: add server side wrapping.
  TODO: add contained link detection.
*/

#import <Foundation/NSException.h>

#import <NGExtensions/NSString+misc.h>

#import <SoObjects/SOGo/NSString+Utilities.h>

#import "UIxMailPartTextViewer.h"

@interface NSString (SOGoMailUIExtension)

- (NSString *) stringByConvertingCRLNToHTML;

@end

@implementation NSString (SOGoMailUIExtension)

#define paddingBuffer 8192

static inline char *
convertChars (const char *oldString, unsigned int oldLength,
	      unsigned int *newLength)
{
  const char *currentChar, *upperLimit;
  char *newString, *destChar, *reallocated;
  unsigned int length, maxLength;
 
  maxLength = oldLength + paddingBuffer;
  newString = NSZoneMalloc (NULL, maxLength + 1);
  destChar = newString;
  currentChar = oldString;

  length = 0;

  upperLimit = oldString + oldLength;
  while (currentChar < upperLimit)
    {
      switch (*currentChar)
	{
	case '\r': break;
	case '\n':
	  length = destChar - newString;
	  if (length + paddingBuffer > maxLength - 6)
	    {
	      maxLength += paddingBuffer;
	      reallocated = NSZoneRealloc (NULL, newString, maxLength + 1);
	      if (reallocated)
		{
		  newString = reallocated;
		  destChar = newString + length;
		}
	      else
		[NSException raise: NSMallocException
			     format: @"reallocation failed in %s",
			     __PRETTY_FUNCTION__];
	    }
	  strcpy (destChar, "<br />");
	  destChar += 6;
	  break;
	default:
	  *destChar = *currentChar;
	  destChar++;
	}
      currentChar++;
    }
  *destChar = 0;
  *newLength = destChar - newString;

  return newString;
}

- (NSString *) stringByConvertingCRLNToHTML
{
  NSString *convertedString;
  char *newString;
  unsigned int newLength;

  newString
    = convertChars ([self cStringUsingEncoding: NSUTF8StringEncoding],
		    [self lengthOfBytesUsingEncoding: NSUTF8StringEncoding],
		    &newLength);
  convertedString = [[NSString alloc] initWithBytes: newString
				      length: newLength
				      encoding: NSUTF8StringEncoding];
  [convertedString autorelease];
  NSZoneFree (NULL, newString);

  return convertedString;
}

@end

@implementation UIxMailPartTextViewer

- (NSString *) flatContentAsString
{
  NSString *superContent;

  superContent = [[super flatContentAsString] stringByEscapingHTMLString];

  return [[superContent stringByDetectingURLs]
	   stringByConvertingCRLNToHTML];
}

@end /* UIxMailPartTextViewer */
