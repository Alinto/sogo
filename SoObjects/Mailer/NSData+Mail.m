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

/*
 * Map a two-byte pair (in JIS mode after ESC$B) from the NEC special character
 * extension area to its Unicode code point.  Returns 0 if the pair is not a
 * known NEC special character.
 *
 * NEC extended the JIS X 0208 standard by assigning characters to rows 9-15
 * (first byte 0x29-0x2F in ESC$B mode), which are undefined in RFC 1468.
 * The mapping here follows the CP50220 / Shift_JIS NEC table.
 *
 * Row 13 (first byte 0x2D):
 *   0x2D21-0x2D34  ①-⑳  U+2460-U+2473  (circled digits 1-20)
 *   0x2D35-0x2D3E  Ⅰ-Ⅹ  U+2160-U+2169  (Roman numerals 1-10)
 */
static unichar
_necSpecialCharForJISBytes(unsigned char b1, unsigned char b2)
{
  if (b1 == 0x2D)
    {
      if (b2 >= 0x21 && b2 <= 0x34)
        return (unichar)(0x2460 + (b2 - 0x21));  /* ①-⑳ */
      if (b2 >= 0x35 && b2 <= 0x3E)
        return (unichar)(0x2160 + (b2 - 0x35));  /* Ⅰ-Ⅹ */
    }
  return 0;
}

/*
 * Decode ISO-2022-JP body data that contains NEC special characters.
 *
 * Standard ISO-2022-JP (RFC 1468) does not define JIS rows 9-15.  Many
 * Japanese Windows email clients (Outlook, etc.) use these rows for NEC
 * special characters (circled digits ①-⑳, Roman numerals, etc.) while still
 * labelling the message as charset=iso-2022-jp.  System iconv implementations
 * (glibc on Linux) reject these byte sequences with EILSEQ.
 *
 * This method parses the escape sequences manually:
 *   - Standard JIS pairs are decoded in bulk via iconv (iso-2022-jp).
 *   - NEC special character pairs are mapped to Unicode directly using
 *     the table above, without going through iconv.
 *
 * Returns nil if the result is empty (caller falls through to UTF-8 fallback).
 */
- (NSString *) bodyStringFromISO2022JPWithNECExtension
{
  const unsigned char *bytes;
  NSUInteger           i, len;
  NSMutableString     *result;
  NSMutableData       *jisChunk;
  BOOL                 inJIS;

  bytes    = [self bytes];
  len      = [self length];
  result   = [NSMutableString stringWithCapacity: len];
  jisChunk = [NSMutableData data];
  inJIS    = NO;
  i        = 0;

  while (i < len)
    {
      unsigned char b = bytes[i];

      /* Detect ISO-2022-JP escape sequences */
      if (b == 0x1B && i + 2 < len)
        {
          unsigned char e1 = bytes[i+1], e2 = bytes[i+2];

          if (e1 == '$' && (e2 == 'B' || e2 == '@'))
            {
              inJIS = YES;
              i += 3;
              continue;
            }
          if (e1 == '(' && (e2 == 'B' || e2 == 'J' || e2 == 'H'))
            {
              /* Flush accumulated JIS pairs before switching to ASCII */
              if ([jisChunk length] > 0)
                {
                  NSMutableData *wrapped;
                  NSString      *s;

                  wrapped = [NSMutableData dataWithCapacity: [jisChunk length] + 6];
                  [wrapped appendBytes: "\x1b$B" length: 3];
                  [wrapped appendData:   jisChunk];
                  [wrapped appendBytes: "\x1b(B" length: 3];
                  s = [NSString stringWithData: wrapped
                                usingEncodingNamed: @"iso-2022-jp"];
                  if (s)
                    [result appendString: s];
                  jisChunk = [NSMutableData data];
                }
              inJIS = NO;
              i += 3;
              continue;
            }
        }

      if (inJIS)
        {
          if (i + 1 < len)
            {
              unsigned char b1 = bytes[i], b2 = bytes[i+1];
              unichar nec = _necSpecialCharForJISBytes(b1, b2);

              if (nec != 0)
                {
                  /* Flush any preceding standard JIS pairs */
                  if ([jisChunk length] > 0)
                    {
                      NSMutableData *wrapped;
                      NSString      *s;

                      wrapped = [NSMutableData dataWithCapacity: [jisChunk length] + 6];
                      [wrapped appendBytes: "\x1b$B" length: 3];
                      [wrapped appendData:   jisChunk];
                      [wrapped appendBytes: "\x1b(B" length: 3];
                      s = [NSString stringWithData: wrapped
                                    usingEncodingNamed: @"iso-2022-jp"];
                      if (s)
                        [result appendString: s];
                      jisChunk = [NSMutableData data];
                    }
                  /* Append the NEC character without going through iconv */
                  [result appendString: [NSString stringWithCharacters: &nec length: 1]];
                  i += 2;
                }
              else
                {
                  /* Standard JIS pair – accumulate for batch iconv decode */
                  [jisChunk appendBytes: &b1 length: 1];
                  [jisChunk appendBytes: &b2 length: 1];
                  i += 2;
                }
            }
          else
            {
              i++; /* trailing odd byte in JIS mode */
            }
        }
      else
        {
          /* ASCII mode – pass byte through directly */
          unichar c = (unichar)b;
          [result appendString: [NSString stringWithCharacters: &c length: 1]];
          i++;
        }
    }

  /* Flush any remaining JIS chunk at end of stream */
  if ([jisChunk length] > 0)
    {
      NSMutableData *wrapped;
      NSString      *s;

      wrapped = [NSMutableData dataWithCapacity: [jisChunk length] + 6];
      [wrapped appendBytes: "\x1b$B" length: 3];
      [wrapped appendData:   jisChunk];
      [wrapped appendBytes: "\x1b(B" length: 3];
      s = [NSString stringWithData: wrapped
                    usingEncodingNamed: @"iso-2022-jp"];
      if (s)
        [result appendString: s];
    }

  return [result length] > 0 ? result : nil;
}

{
  NSString *lcCharset, *bodyString;

  if ([charset length])
    lcCharset = [charset lowercaseString];
  else
    lcCharset = @"us-ascii";

  bodyString = [NSString stringWithData: self usingEncodingNamed: lcCharset];

  /* Many Japanese emails declare charset=iso-2022-jp but actually use
     Microsoft's extended variant (cp50220 / ISO-2022-JP-MS), which
     includes NEC special characters (circled digits ①-⑳, etc.) located
     at JIS row 13.  This row is undefined in standard ISO-2022-JP
     (RFC 1468), so strict iconv implementations return EILSEQ and the
     conversion fails (returns nil).  Because ISO-2022-JP is a 7-bit
     encoding every byte is also valid UTF-8, so the UTF-8 fallback
     below would "succeed" and render the raw escape sequences as ASCII
     garbage.
     Try cp50220 first (works with GNU libiconv, e.g. on macOS), then
     fall back to our built-in NEC decoder which does not depend on
     iconv support (works with glibc iconv on Linux/Ubuntu). */
  if (!bodyString && [lcCharset isEqualToString: @"iso-2022-jp"])
    {
      bodyString = [NSString stringWithData: self usingEncodingNamed: @"cp50220"];
      if (!bodyString)
        bodyString = [self bodyStringFromISO2022JPWithNECExtension];
    }

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

      len = [d length];
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
