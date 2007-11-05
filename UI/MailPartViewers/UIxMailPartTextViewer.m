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

#import <NGExtensions/NSString+misc.h>

#import <SoObjects/SOGo/NSString+Utilities.h>

#import "UIxMailPartTextViewer.h"

@interface NSString (SOGoMailUIExtension)

- (NSString *) stringByConvertingCRLNToHTML;

@end

@implementation NSString (SOGoMailUIExtension)

- (NSString *) stringByConvertingCRLNToHTML
{
  NSString *convertedString;
  const char *oldString, *currentChar;
  char *newString, *destChar;
  unsigned int oldLength, length, delta;

  oldString = [self cStringUsingEncoding: NSUTF8StringEncoding];
  oldLength = [self lengthOfBytesUsingEncoding: NSUTF8StringEncoding];

  length = oldLength;
  newString = malloc (length + 500);
  destChar = newString;
  currentChar = oldString;
  while (currentChar < (oldString + oldLength))
    {
      if (*currentChar != '\r')
	{
	  if (*currentChar == '\n')
	    {
	      strcpy (destChar, "<br />");
	      destChar += 6;
	      delta = (destChar - newString);
	      if (delta > length)
		{
		  length += 500;
		  newString = realloc (newString, length + 500);
		  destChar = newString + delta;
		}
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

  convertedString = [[NSString alloc] initWithBytes: newString
				      length: (destChar + 1 - newString)
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

  return [[superContent stringByDetectingURLs] stringByConvertingCRLNToHTML];
}

@end /* UIxMailPartTextViewer */
