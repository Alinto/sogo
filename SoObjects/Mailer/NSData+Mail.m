/* NSData+Mail.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2017 Inverse inc.
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
#import <Foundation/NSString.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGExtensions/NSObject+Logs.h>

#import "NSData+Mail.h"

@implementation NSData (SOGoMailUtilities)

- (NSData *) bodyDataFromEncoding: (NSString *) encoding
{
  NSString *realEncoding;
  NSData *decodedData;

  if ([encoding length] > 0)
    {
      realEncoding = [encoding lowercaseString];

      if ([realEncoding isEqualToString: @"7bit"]
          || [realEncoding isEqualToString: @"8bit"]
	  || [realEncoding isEqualToString: @"binary"])
        decodedData = self;
      else if ([realEncoding isEqualToString: @"base64"])
        decodedData = [self dataByDecodingBase64];
      else if ([realEncoding isEqualToString: @"quoted-printable"])
        decodedData = [self dataByDecodingQuotedPrintableTransferEncoding];
      else
        {
          decodedData = nil;
          //NSLog (@"encoding '%@' unknown, returning nil data", realEncoding);
        }
    }
  else
    decodedData = self;

  return decodedData;
}

- (NSString *) bodyStringFromCharset: (NSString *) charset
{
  NSString *lcCharset, *bodyString;

  if ([charset length])
    lcCharset = [charset lowercaseString];
  else
    lcCharset = @"us-ascii";

  bodyString = [NSString stringWithData: self usingEncodingNamed: lcCharset];
  if (![bodyString length])
    {
      /* UTF-8 is used as a 8bit fallback charset... */
      bodyString = [[NSString alloc] initWithData: self
                                         encoding: NSUTF8StringEncoding];
      [bodyString autorelease];
    }

  if (!bodyString)
    {
      /*
        iCalendar invitations sent by Outlook 2002 have the annoying bug that the
        mail states an UTF-8 content encoding but the actual iCalendar content is
        encoding in Latin-1 (or Windows Western?).
	
        As a result the content decoding will fail (TODO: always?). In this case we
        try to decode with Latin-1.
        
        Note: we could check for the Outlook x-mailer, but it was considered better
        to try Latin-1 as a fallback in any case (be tolerant).
      */
      
      bodyString = [[NSString alloc] initWithData: self
                                         encoding: NSISOLatin1StringEncoding];
      if (!bodyString)
        [self errorWithFormat: @"an attempt to use"
              @" NSISOLatin1StringEncoding as callback failed"];
      [bodyString autorelease];
    }

  return bodyString;
}

/*
 * Excpected form is: "=?charset?encoding?encoded text?=".
 */
- (NSString *) decodedHeader
{
  const char *cData;
  unsigned int len, i, j;
  NSString *decodedString;

  cData = [self bytes];
  len = [self length];
  decodedString = nil;

  if (len)
    {
      if (len > 6)
	{
	  // Find beginning of encoded text
	  i = 1;
	  while ((*cData != '=' || *(cData+1) != '?') && i < len)
	    {
	      cData++;
	      i++;
	    }

	  if (*cData == '=' && *(cData+1) == '?')
	    {
	      NSString *enc;

	      if (i > 1)
		decodedString = [[[NSString alloc] initWithData: [self subdataWithRange: NSMakeRange(0, (i-1))]
							encoding: NSASCIIStringEncoding] autorelease];
	      cData += 2; // skip "=?"
	      i++;
	      j = i;
	      // Find next "?"
	      while (*cData != '?' && j < len)
		{
		  cData++;
		  j++;
		}
	      enc = [[[NSString alloc] initWithData:[self subdataWithRange: NSMakeRange(i, j-i)]
				       encoding: NSASCIIStringEncoding] autorelease];

	      i = j + 3; // skip "?q?"
	      if (i < (len-2))
		{
		  NSData *d;
		  BOOL isQuotedPrintable = NO;

		  cData++;
		  // We check if we have a QP or Base64 encoding
		  if (*cData == 'q' || *cData == 'Q')
		    isQuotedPrintable = YES;

		  // Find end of encoded text
		  j = i;
		  cData += 2; // skip "q?"
		  while ((*cData != '?' || *(cData+1) != '=') && (j+1) < len)
		    {
		      cData++;
		      j++;
		    }

		  d = [self subdataWithRange: NSMakeRange(i, j-i)];
		  if (isQuotedPrintable)
		    d = [d dataByDecodingQuotedPrintable];
		  else
		    d = [d dataByDecodingBase64];

		  if (decodedString)
		    {
		      decodedString = [NSString stringWithFormat: @"%@%@",
						decodedString, [NSString stringWithData: d
								     usingEncodingNamed: enc]];
		    }
		  else
		    decodedString = [NSString stringWithData: d
					  usingEncodingNamed: enc];

		  j += 2; // skip "?="
		  if (j < len)
		    {
		      // Recursively decode the remaining part
		      decodedString = [NSString stringWithFormat: @"%@%@",
						decodedString,
					 [[self subdataWithRange: NSMakeRange(j, len-j)] decodedHeader]];
		    }
		}
	      else
		decodedString = nil;
	    }
	}
      if (!decodedString)
	{
	  decodedString
	    = [[NSString alloc] initWithData: self
				encoding: NSUTF8StringEncoding];
	  if (!decodedString)
	    decodedString
	      = [[NSString alloc] initWithData: self
				  encoding: NSISOLatin1StringEncoding];
	  [decodedString autorelease];
	}
    }
  else
    decodedString = @"";

  return decodedString;
}

//
// In order to avoid a libxml bug/limitation, we strip the charset= parameter
// to avoid libxml to consider the charset= parameter while it works in UTF-8
// internally, all the time.
//
// A fix was commited by Daniel Veillard following discussions Inverse had
// with him on the issue:
//
// commit a1bc2f2ba4b5317885205d4f71c7c4b1c99ec870
// Author: Daniel Veillard <veillard redhat com>
// Date:   Mon May 16 16:03:50 2011 +0800
//
//     Add options to ignore the internal encoding
//
//     For both XML and HTML, the document can provide an encoding
//     either in XMLDecl in XML, or as a meta element in HTML head.
//     This adds options to ignore those encodings if the encoding
//     is known in advace for example if the content had been converted
//     before being passed to the parser.
//
//     * parser.c include/libxml/parser.h: add XML_PARSE_IGNORE_ENC option
//       for XML parsing
//     * include/libxml/HTMLparser.h HTMLparser.c: adds the
//       HTML_PARSE_IGNORE_ENC for HTML parsing
//     * HTMLtree.c: fix the handling of saving when an unknown encoding is
//       defined in meta document header
//     * xmllint.c: add a --noenc option to activate the new parser options
//
//
- (NSData *) sanitizedContentUsingVoidTags: (NSArray *) theVoidTags
{
  NSMutableData *d;
  NSString *found_tag, *tag;
  NSEnumerator *tags;
  const char *bytes;
  char *buf;
  int i, j, len;
  BOOL found_delimiter, in_meta, delete_html_end_tag;

  d = [NSMutableData dataWithData: self];
  bytes = [d bytes];
  len = [d length];
  i = 0;

  in_meta = NO;
  delete_html_end_tag = NO;

  while (i < len)
    {
      // We check if we see <meta ...> in which case, we substitute de charset= stuff.
      if (i < len-5)
	{
	  if ((*bytes == '<') &&
	      (*(bytes+1) == 'm' || *(bytes+1) == 'M') &&
	      (*(bytes+2) == 'e' || *(bytes+2) == 'E') &&
	      (*(bytes+3) == 't' || *(bytes+3) == 'T') &&
	      (*(bytes+4) == 'a' || *(bytes+4) == 'A') &&
	      (*(bytes+5) == ' '))
            in_meta = YES;
	}

      // We search for something like :
      //
      // <meta http-equiv="Content-Type" content="text/html; charset=Windows-1252">
      //
      if (in_meta && i < len-9)
	{
	  if ((*bytes == 'c' || *bytes == 'C') &&
	      (*(bytes+1) == 'h' || *(bytes+1) == 'H') &&
	      (*(bytes+2) == 'a' || *(bytes+2) == 'A') &&
	      (*(bytes+3) == 'r' || *(bytes+3) == 'R') &&
	      (*(bytes+4) == 's' || *(bytes+4) == 'S') &&
	      (*(bytes+5) == 'e' || *(bytes+5) == 'E') &&
	      (*(bytes+6) == 't' || *(bytes+6) == 'T') &&
	      (*(bytes+7) == '='))
	    {
	      // We search until we find a '"' or a space
	      j = 8;
              found_delimiter = YES;

	      while (*(bytes+j) != ' ' && *(bytes+j) != '"' && *(bytes+j) != '\'')
		{
		  j++;

		  // We haven't found anything, let's return the data untouched
		  if ((i+j) >= len)
                    {
                      in_meta = found_delimiter = NO;
                      break;
                    }
		}

              if (found_delimiter)
                {
                  [d replaceBytesInRange: NSMakeRange(i, j)
                               withBytes: NULL
                                  length: 0];
                  in_meta = found_delimiter = NO;
                }
	    }
	}

      bytes++;
      i++;
    }

  /*
   * Replace badly formatted void tags
   *
   * A void tag that begins with a slash is considered invalid.
   * We remove the slash from those tags.
   *
   * Ex: </br> is replaced by <br>
   */

  if (!theVoidTags)
    {
      /* see http://www.w3.org/TR/html4/index/elements.html */
      theVoidTags = [[[NSArray alloc] initWithObjects: @"area", @"base",
                                      @"basefont", @"br", @"col", @"frame", @"hr",
                                      @"img", @"input", @"isindex", @"link",
                                      @"meta", @"param", @"", nil] autorelease];
    }

  bytes = [d bytes];
  len = [d length];
  i = 0;
  while (i < len)
    {
      if (i < len-3)
	{
          // Search for ending tags
	  if ((*bytes == '<') && (*(bytes+1) == '/'))
            {
              i += 2;
              bytes += 2;
              j = 0;
              found_delimiter = YES;

              while (*(bytes+j) != '>')
                {
                  j++;
                  if ((i+j) >= len)
                    {
                      found_delimiter = NO;
                      break;
                    }
                }

              if (found_delimiter && j > 0)
                {
                  // Copy the ending tag to a NSString
                  buf = malloc((j+1) * sizeof(char));
                  memset (buf, 0, j+1);
                  memcpy (buf, bytes, j);
                  found_tag = [NSString stringWithCString: buf encoding: NSUTF8StringEncoding];

                  tags = [theVoidTags objectEnumerator];
                  tag = [tags nextObject];
                  while (tag && found_tag)
                    {
                      if ([tag caseInsensitiveCompare: found_tag] == NSOrderedSame)
                        {
                          // Remove the leading slash
                          //NSLog(@"Found void tag with invalid leading slash: </%@>", found_tag);
                          i--;
                          [d replaceBytesInRange: NSMakeRange(i, 1)
                                       withBytes: NULL
                                          length: 0];
                          bytes = [d bytes];
                          bytes += i;
                          len = [d length];
                          break;
                        }
                      tag = [tags nextObject];
                    }

                  if ([@"html" caseInsensitiveCompare: found_tag] == NSOrderedSame)
                    {
                      // Remove </html>
                      delete_html_end_tag = YES;
                      i -= 2;
                      [d replaceBytesInRange: NSMakeRange(i, 7)
                                   withBytes: NULL
                                      length: 0];
                      bytes = [d bytes];
                      bytes += i;
                      len = [d length];
                    }

                  free(buf);

                  // Continue the parsing after end tag
                  i += j;
                  bytes += j;
                }
            }
        }

      bytes++;
      i++;
    }

  if (delete_html_end_tag)
    [d appendBytes: "</html>" length: 7];

  return d;
}

@end
