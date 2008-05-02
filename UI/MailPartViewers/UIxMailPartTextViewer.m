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

static inline char *
convertChars (const char *oldString, unsigned int oldLength,
	      unsigned int *newLength)
{
  const char *currentChar, *upperLimit;
  char *newString, *destChar, *reallocated;
  unsigned int length, maxLength, iteration;

  maxLength = oldLength + 500;
  newString = malloc (maxLength);
  destChar = newString;
  currentChar = oldString;

  length = 0;
  iteration = 0;

  upperLimit = oldString + oldLength;
  while (currentChar < upperLimit)
    {
      if (*currentChar != '\r')
	{
	  if (*currentChar == '\n')
	    {
	      length = destChar - newString;
	      if ((length + (6 * iteration) + 500) > maxLength)
		{
		  maxLength = length + (iteration * 6) + 500;
		  reallocated = realloc (newString, maxLength);
		  if (reallocated)
		    newString = reallocated;
		  else
		    [NSException raise: NSMallocException
				 format: @"reallocation failed in %s",
				 __PRETTY_FUNCTION__];
		  destChar = newString + length;
		}
	      strcpy (destChar, "<br />");
	      destChar += 6;
	      iteration++;
	    }
	  else
	    {
	      *destChar = *currentChar;
	      destChar++;
	    }
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
  free (newString);

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
