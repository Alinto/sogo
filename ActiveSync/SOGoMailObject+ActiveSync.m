/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Inverse inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#include "SOGoMailObject+ActiveSync.h"

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>

#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGExtensions/NGHashMap.h>
#import <NGImap4/NGImap4Envelope.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>
#import <NGImap4/NSString+Imap4.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WORequest.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeFileData.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeType.h>
#import <NGMail/NGMimeMessageParser.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>

#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/NSArray+Utilities.h>

#include "iCalTimeZone+ActiveSync.h"
#include "NSData+ActiveSync.h"
#include "NSDate+ActiveSync.h"
#include "NSString+ActiveSync.h"

#include <Appointments/iCalEntityObject+SOGo.h>
#include <Appointments/iCalPerson+SOGo.h>
#include <Mailer/SOGoMailBodyPart.h>
#include <Mailer/NSString+Mail.h>

#import <Mailer/SOGoMailLabel.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailObject.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>

#include <SOGo/SOGoUser.h>
#include <SOGo/NSString+Utilities.h>

#import <Appointments/SOGoAptMailNotification.h>



unsigned char strToChar(char a, char b) {
    char encoder[3] = {'\0','\0','\0'};
    encoder[0] = a;
    encoder[1] = b;
    return (char) strtol(encoder,NULL,16);
}

@interface NSString (NSStringExtensions)
- (NSData *) decodeFromHexidecimal;
@end

@implementation NSString (NSStringExtensions)

- (NSData *) decodeFromHexidecimal;
{
    const char * bytes = [self cStringUsingEncoding: NSUTF8StringEncoding];
    NSUInteger length = strlen(bytes);
    unsigned char * r = (unsigned char *) malloc(length / 2 + 1);
    unsigned char * index = r;

    while ((*bytes) && (*(bytes +1))) {
        *index = strToChar(*bytes, *(bytes +1));
        index++;
        bytes+=2;
    }
    *index = '\0';

    NSData * result = [NSData dataWithBytes: r length: length / 2];
    free(r);

    return result;
}

@end

typedef struct {
  uint32_t dwLowDateTime;
  uint32_t dwHighDateTime;
} FILETIME;

struct GlobalObjectId {
  uint8_t                   ByteArrayID[16];
  uint8_t                   YH;
  uint8_t                   YL;
  uint8_t                   Month;
  uint8_t                   D;
  FILETIME                  CreationTime;
  uint8_t                   X[8];
  uint32_t                  Size;
  uint8_t Data[0];
};

@implementation SOGoMailObject (ActiveSync)

//
//
//
- (void) _setInstanceDate: (struct GlobalObjectId *) newGlobalId
                 fromDate: (NSCalendarDate *) instanceDate
{
  uint16_t year;

  if (instanceDate)
    {
      //[instanceDate setTimeZone: timeZone];
      year = [instanceDate yearOfCommonEra];
      newGlobalId->YH = year >> 8;
      newGlobalId->YL = year & 0xff;
      newGlobalId->Month = [instanceDate monthOfYear];
      newGlobalId->D = [instanceDate dayOfMonth];
    }
}

//
// The GlobalObjId is documented here: http://msdn.microsoft.com/en-us/library/ee160198(v=EXCHG.80).aspx
//

- (NSData *) _computeGlobalObjectIdFromEvent: (iCalEvent *) event
{
  NSData *binPrefix, *globalObjectId, *uidAsASCII;
  NSString *prefix, *uid;
  struct GlobalObjectId *newGlobalId;
  const char *bytes;

  uid = [event uid];
  uidAsASCII = [uid dataUsingEncoding: NSASCIIStringEncoding];
  newGlobalId = (struct GlobalObjectId*)calloc(sizeof(uint8_t), sizeof(struct GlobalObjectId) + 0x0c + [uidAsASCII length]);

  prefix = @"040000008200e00074c5b7101a82e008";

  // dataPrefix is "vCal-Uid %x01 %x00 %x00 %x00"
  uint8_t dataPrefix[] = { 0x76, 0x43, 0x61, 0x6c, 0x2d, 0x55, 0x69, 0x64, 0x01, 0x00, 0x00, 0x00 };

  binPrefix = [prefix convertHexStringToBytes];
  [binPrefix getBytes: &newGlobalId->ByteArrayID];
  [self _setInstanceDate: newGlobalId
                fromDate: [event recurrenceId]];
  bytes = [uidAsASCII bytes];

  // 0x0c is the size of our dataPrefix
  newGlobalId->Size = 0x0c + [uidAsASCII length];
  memcpy(newGlobalId->Data, dataPrefix, 0x0c);
  memcpy(newGlobalId->Data + 0x0c, bytes, newGlobalId->Size - 0x0c);

  globalObjectId = [[NSData alloc] initWithBytes: newGlobalId  length: 40 + newGlobalId->Size*sizeof(uint8_t)];
  free(newGlobalId);
  return [globalObjectId autorelease];
}


//
// For debugging purposes...
//
- (NSString *) _uidFromGlobalObjectId: (NSData *) objectId
{
  NSString *uid;

  struct GlobalObjectId *newGlobalId;
  NSUInteger length;
  uint8_t *bytes;

  length = [objectId length];
  uid = nil;

  bytes = malloc(length*sizeof(uint8_t));
  [objectId getBytes: bytes  length: length];

  newGlobalId = (struct GlobalObjectId *)bytes;

  // We must take the offset (dataPrefix) into account
  uid = [[NSString alloc] initWithBytes: newGlobalId->Data+12  length: newGlobalId->Size-12 encoding: NSASCIIStringEncoding];
  free(bytes);

  return AUTORELEASE(uid);
}

//
//
//
- (NSString *) _emailAddressesFrom: (NSArray *) enveloppeAddresses
{
  NGImap4EnvelopeAddress *address;
  NSString *email, *rc, *name;
  NSMutableArray *addresses;
  int i, max;

  rc = nil;
  max = [enveloppeAddresses count];

  if (max > 0)
    {
      addresses = [NSMutableArray array];
      for (i = 0; i < max; i++)
        {
          address = [enveloppeAddresses objectAtIndex: i];
          name = [address personalName];
          email = [NSString stringWithFormat: @"\"%@\" <%@>", (name ? name : [address baseEMail]), [address baseEMail]];
          
          if (email)
            [addresses addObject: email];
        }
      rc = [addresses componentsJoinedByString: @", "];
    }

  return rc;
}

//
//
//
- (NSData *) _preferredBodyDataInMultipartUsingType: (int) theType
                                    nativeTypeFound: (int *) theNativeTypeFound
{
  NSString *encoding, *key, *plainKey, *htmlKey, *type, *subtype;
  NSDictionary *textParts, *part;
  NSEnumerator *e;
  NSData *d;

  BOOL ignore;

  textParts = [self fetchPlainTextParts];
  e = [textParts keyEnumerator];
  plainKey = nil;
  htmlKey = nil;
  d = nil;

  while ((key = [e nextObject]))
    {
      // Walk the hierarchy up and check whether parents are of type mulipart - i.e. ignore message/rfc822
      if ([key countOccurrencesOfString: @"."] > 0)
        {
          NSMutableArray *a;

          a = [[[key componentsSeparatedByString: @"."] mutableCopy] autorelease];
          ignore = NO;

          while ([a count] > 0)
            {
              [a removeLastObject];
              part = [self lookupInfoForBodyPart: [a componentsJoinedByString: @"."]];

              if (![[part valueForKey: @"type"] isEqualToString: @"multipart"])
                ignore = YES;
            }

          if (ignore)
            continue;
        }

      part = [self lookupInfoForBodyPart: key];
      type = [part valueForKey: @"type"];
      subtype = [part valueForKey: @"subtype"];
      
      // Don't select an attachment as body
      if ([[[part valueForKey: @"disposition"] valueForKey: @"type"] isEqualToString: @"attachment"])
         continue;

      if ([type isEqualToString: @"text"] && [subtype isEqualToString: @"html"])
        htmlKey = key;
      else if ([type isEqualToString: @"text"] && [subtype isEqualToString: @"plain"])
        plainKey = key;
    }

  key = nil;
  *theNativeTypeFound = 1;

  if (theType == 2 && htmlKey)
    {
      key = htmlKey;
      *theNativeTypeFound = 2;
    }
  else if (theType == 1 && plainKey)
    key = plainKey;
  else if (theType == 2 && plainKey)
    key = plainKey;
  else if (theType == 1 && htmlKey)
    {
      key = htmlKey;
      *theNativeTypeFound = 2;
    }

  if (key)
    {
      NSString *s, *charset;
      
      d = [[self fetchPlainTextParts] objectForKey: key];

      encoding = [[self lookupInfoForBodyPart: key] objectForKey: @"encoding"];
      
      if ([encoding caseInsensitiveCompare: @"base64"] == NSOrderedSame)
        d = [d dataByDecodingBase64];
      else if ([encoding caseInsensitiveCompare: @"quoted-printable"] == NSOrderedSame)
        d = [d dataByDecodingQuotedPrintableTransferEncoding];

      charset = [[[self lookupInfoForBodyPart: key] objectForKey: @"parameterList"] objectForKey: @"charset"];

      if (![charset length])
        charset = @"utf-8";
      
      s = [NSString stringWithData: d  usingEncodingNamed: charset];

      // We fallback to ISO-8859-1 string encoding
      if (!s)
        s = [[[NSString alloc] initWithData: d  encoding: NSISOLatin1StringEncoding] autorelease];

      if (theType == 1 && *theNativeTypeFound == 2)
        s = [s htmlToText];

      d = [s dataUsingEncoding: NSUTF8StringEncoding];
    }

  return d;
}

//
//
//
- (void) _sanitizedMIMEPart: (id) thePart
                  performed: (BOOL *) b
{
  if ([thePart isKindOfClass: [NGMimeMultipartBody class]])
    {
      NGMimeBodyPart *part;
      NSArray *parts;
      int i;

      parts = [thePart parts];
      
      for (i = 0; i < [parts count]; i++)
        {
          part = [parts objectAtIndex: i];

          [self _sanitizedMIMEPart: part
                         performed: b];
        }
    }
  else if ([thePart isKindOfClass: [NGMimeBodyPart class]] || [thePart isKindOfClass: [NGMimeMessage class]])
    {
      NGMimeFileData *fdata;
      id body;

      body = [thePart body];

      if ([body isKindOfClass: [NGMimeMultipartBody class]])
        {
          [self _sanitizedMIMEPart: body
                         performed: b];
        }
      else if (([body isKindOfClass: [NSData class]] || [body isKindOfClass: [NSString class]]) &&
               [[[thePart contentType] type] isEqualToString: @"text"] &&
               ([[[thePart contentType] subType] isEqualToString: @"plain"] || [[[thePart contentType] subType] isEqualToString: @"html"]))
        {
          // We make sure everything is encoded in UTF-8.
          NGMimeType *mimeType;
          NSString *s;

          if ([body isKindOfClass: [NSData class]])
            {
              NSString *charset;
 
              charset = [[thePart contentType] valueOfParameter: @"charset"];

              if (![charset length])
                charset = @"utf-8";
              
              s = [NSString stringWithData: body usingEncodingNamed: charset];

              // We fallback to ISO-8859-1 string encoding. We avoid #3103.
              if (!s)
                s = [[[NSString alloc] initWithData: body  encoding: NSISOLatin1StringEncoding] autorelease];
            }
          else
            {
              // Handle situations when SOPE stupidly returns us a NSString
              // This can happen for Content-Type: text/plain, Content-Transfer-Encoding: 8bit
              s = body;
            }

          if (s)
            {
              body = [s dataUsingEncoding: NSUTF8StringEncoding];
            }

          mimeType = [NGMimeType mimeType: [[thePart contentType] type]
                                  subType: [[thePart contentType] subType]
                               parameters: [NSDictionary dictionaryWithObject: @"utf-8"  forKey: @"charset"]];
          [(NGMimeBodyPart *)thePart setHeader: mimeType  forKey: @"content-type"];
          
          fdata = [[NGMimeFileData alloc] initWithBytes: [body bytes]
                                                 length: [body length]];
          
          [thePart setBody: fdata];                  
          RELEASE(fdata);
          *b = YES;
        }
    }
}

//
//
//
- (NSData *) _sanitizedMIMEMessage
{
  NGMimeMessageParser *parser;
  NGMimeMessage *message;
  NSData *d;
  
  BOOL b;
  
  d = [self content];

  parser = [[NGMimeMessageParser alloc] init];
  AUTORELEASE(parser);
  
  message = [parser parsePartFromData: d];
  b = NO;

  if (message)
    {
      [self _sanitizedMIMEPart: message  performed: &b];

      if (b)
        {
          NGMimeMessageGenerator *generator;
          
          generator = [[NGMimeMessageGenerator alloc] init];
          AUTORELEASE(generator);
          
          d = [generator generateMimeFromPart: message];
        }
    }
  
  return d;
}

//
//
//
- (BOOL) _sanitinizeNeeded: (NSArray *) theParts
{
  NSString *encoding, *charset;
  int i;

  for (i = 0; i < [theParts count]; i++)
    {
      encoding = [[theParts objectAtIndex: i ] objectForKey: @"encoding"];
      charset = [[[theParts objectAtIndex: i ] objectForKey: @"parameterList"] objectForKey: @"charset"];
      if (encoding && ([encoding caseInsensitiveCompare: @"7bit"] == NSOrderedSame || [encoding caseInsensitiveCompare: @"8bit"] == NSOrderedSame) &&
          charset  && ![charset caseInsensitiveCompare: @"utf-8"] == NSOrderedSame
                   && ![charset caseInsensitiveCompare: @"us-ascii"] == NSOrderedSame)
        {
          return YES;
        }

      if ([self _sanitinizeNeeded: [[theParts objectAtIndex: i ] objectForKey: @"parts"]])
          return YES;
   }

   return NO;
}


- (BOOL) _isSigned: (NSDictionary *) thePart
{
  NSMutableDictionary *currentPart;
  NSArray *subparts;
  NSString *type, *subtype;
  NSUInteger i;

  type = [[thePart objectForKey: @"type"] lowercaseString];
  subtype = [[thePart objectForKey: @"subtype"] lowercaseString];

  if ([type isEqualToString: @"multipart"])
    {
      if ([subtype isEqualToString: @"signed"])
        return YES;

      subparts = [thePart objectForKey: @"parts"];
      for (i = 0; i < [subparts count]; i++)
        {
          currentPart = [subparts objectAtIndex: i];
          if ([self _isSigned: currentPart])
            return YES;
        }
    }

  return NO;
}

- (BOOL) _isSmimeEncrypted: (NSDictionary *) thePart
{
  NSMutableDictionary *currentPart;
  NSArray *subparts;
  NSString *type, *subtype;
  NSUInteger i;

  type = [[thePart objectForKey: @"type"] lowercaseString];
  subtype = [[thePart objectForKey: @"subtype"] lowercaseString];

  if ([type isEqualToString: @"multipart"])
    {
      subparts = [thePart objectForKey: @"parts"];
      for (i = 0; i < [subparts count]; i++)
        {
          currentPart = [subparts objectAtIndex: i];
          if ([self _isSmimeEncrypted: currentPart])
            return YES;
        }
    }
  else if ([type isEqualToString: @"application"] && ([subtype isEqualToString: @"pkcs7-mime"] ||
           [subtype isEqualToString: @"x-pkcs7-mime"]))
    return YES;

  return NO;
}

- (BOOL) _isPGP: (NSDictionary *) thePart
{
  NSMutableDictionary *currentPart;
  NSArray *subparts;
  NSString *type, *subtype, *protocol;
  NSUInteger i;

  type = [[thePart objectForKey: @"type"] lowercaseString];
  subtype = [[thePart objectForKey: @"subtype"] lowercaseString];
  protocol = [[[thePart objectForKey: @"parameterList"] objectForKey: @"protocol"] lowercaseString];

  if ([type isEqualToString: @"multipart"])
    {
      if (([protocol isEqualToString: @"application/pgp-signature"] || [protocol isEqualToString: @"application/pgp-encrypted"]))
        return YES;

      subparts = [thePart objectForKey: @"parts"];
      for (i = 0; i < [subparts count]; i++)
        {
          currentPart = [subparts objectAtIndex: i];
          if ([self _isPGP: currentPart])
            return YES;
        }
    }
  else if ([type isEqualToString: @"application"] && [subtype isEqualToString: @"pgp-encrypted"])
    return YES;

  return NO;
}

//
//
//
- (NSData *) _preferredBodyDataUsingType: (int) theType
                              mimeSupport: (int) theMimeSupport
                              nativeType: (int *) theNativeType
{
  NSString *type, *subtype, *encoding;
  NSData *d;
  BOOL isSMIME, sanitinizeNeeded;
  
  type = [[[self bodyStructure] valueForKey: @"type"] lowercaseString];
  subtype = [[[self bodyStructure] valueForKey: @"subtype"] lowercaseString];
  isSMIME = NO;
  d = nil;
  
  // We determine the native type
  if ([type isEqualToString: @"text"] && [subtype isEqualToString: @"plain"])
    *theNativeType = 1;
  else if ([type isEqualToString: @"text"] && [subtype isEqualToString: @"html"])
    *theNativeType = 2;
  else if ([type isEqualToString: @"multipart"])
    *theNativeType = 4;

  if (([self _isSigned: [self bodyStructure]] ||
       [self _isSmimeEncrypted: [self bodyStructure]] ||
       [self _isPGP: [self bodyStructure]]) && theMimeSupport > 0)
    {
      *theNativeType = 4;
      isSMIME = YES;
    }

  // We get the right part based on the preference
  if ((theType == 1 || theType == 2) && !isSMIME)
    {
      if ([type isEqualToString: @"text"] && ![subtype isEqualToString: @"calendar"])
        {
          NSString *s, *charset;
          
          charset = [[[self lookupInfoForBodyPart: @""] objectForKey: @"parameterList"] objectForKey: @"charset"];
          
          if (![charset length])
            charset = @"utf-8";
          
          d = [[self fetchPlainTextParts] objectForKey: @""];
          
          // We check if we have base64 encoded parts. If so, we just
          // un-encode them before using them
          encoding = [[self lookupInfoForBodyPart: @""] objectForKey: @"encoding"];

          if ([encoding caseInsensitiveCompare: @"base64"] == NSOrderedSame)
            d = [d dataByDecodingBase64];
          else if ([encoding caseInsensitiveCompare: @"quoted-printable"] == NSOrderedSame)
            d = [d dataByDecodingQuotedPrintableTransferEncoding];

          s = [NSString stringWithData: d  usingEncodingNamed: charset];

          // We fallback to ISO-8859-1 string encoding. We avoid #3103.
          if (!s)
            s = [[[NSString alloc] initWithData: d  encoding: NSISOLatin1StringEncoding] autorelease];
          
          // Check if we must convert html->plain
          if (theType == 1 && [subtype isEqualToString: @"html"])
            {
              s = [s htmlToText];
            }

          d = [s dataUsingEncoding: NSUTF8StringEncoding];
        }
      else if ([type isEqualToString: @"multipart"])
        {
          d = [self _preferredBodyDataInMultipartUsingType: theType nativeTypeFound: theNativeType];
        }
    }
  else if (theType == 4 || isSMIME)
    {
      // We sanitize the content if the content-transfer-encoding is 8bit and charset is not utf-8 or us-ascii.
      sanitinizeNeeded = [self _sanitinizeNeeded: [NSArray arrayWithObject: [self bodyStructure]]];

      if (sanitinizeNeeded && !isSMIME)
        d = [self _sanitizedMIMEMessage];
      else
        d = [self content];
    }

  return d;
}


- (NSString *) _getNormalizedSubject
{
  NSString *subject;
  NSUInteger colIdx;
  NSString *stringValue;

  subject = [[self subject] decodedHeader];

  colIdx = [subject rangeOfString: @":" options:NSBackwardsSearch].location;
  if (colIdx != NSNotFound && colIdx + 1 < [subject length])
    stringValue = [[subject substringFromIndex: colIdx + 1] stringByTrimmingLeadSpaces];
  else
    stringValue = subject;

  if (!stringValue)
    stringValue = @"";

  return stringValue;
}


- (NSString *) _truncateContent: (NSString *) theContent
                          limit: (int) theLimit
                      truncated: (int *) wasTruncated
{
  if ([theContent length] > theLimit)
    {
      int i, len;

      theContent = [theContent substringToIndex: theLimit];
      *wasTruncated = 1;

      // We search for the first "space" character starting from the
      // end and we truncate the string once more. We do this to avoid
      // truncating the content in the middle of a XML entity
      len = theLimit-1;

      for (i = len; i >= 0; i--)
        {
          if (isspace([theContent characterAtIndex: i]))
            break;
        }

      return [theContent substringToIndex: i];
    }

  *wasTruncated = 0;
  return theContent;
}

//
//
//
- (iCalCalendar *) _calendarFromParts: (NSArray *) parts
			       parent: (id) parent
{
  NSDictionary *part;
  id bodyPart;
  int i;

  for (i = 0; i < [parts count]; i++)
    {
      part = [parts objectAtIndex: i];
      bodyPart = [parent lookupImap4BodyPartKey: [NSString stringWithFormat: @"%d", i+1]
				      inContext: self->context];

      if ([[part objectForKey: @"type"] isEqualToString: @"text"] &&
	  [[part objectForKey: @"subtype"] isEqualToString: @"calendar"])
	{
	  if (bodyPart)
	    {
	      iCalCalendar *calendar;
	      NSData *calendarData;

	      calendarData = [bodyPart fetchBLOBWithPeek: YES];
	      calendar = nil;

	      NS_DURING
		calendar = [iCalCalendar parseSingleFromSource: calendarData];
	      NS_HANDLER
		calendar = nil;
	      NS_ENDHANDLER

	      return calendar;
	    }
	}
      else if ([[part objectForKey: @"type"] isEqualToString: @"multipart"])
	return [self _calendarFromParts: [part objectForKey: @"parts"]  parent: bodyPart];
    }

  return nil;
}

//
//
//
- (iCalCalendar *) calendarFromIMIPMessage
{
  NSString *type, *subtype;
  NSArray *parts;

  type = [[[self bodyStructure] valueForKey: @"type"] lowercaseString];
  subtype = [[[self bodyStructure] valueForKey: @"subtype"] lowercaseString];

  // process mail of type text/calendar
  if ([type isEqualToString: @"text"] && [subtype isEqualToString: @"calendar"])
    {
      iCalCalendar *calendar;
      NSString *encoding;
      NSData *calendarData;

      encoding = [[[self bodyStructure] valueForKey: @"encoding"] lowercaseString];
      calendarData = [[self fetchPlainTextParts] objectForKey: @""];

      if ([encoding caseInsensitiveCompare: @"base64"] == NSOrderedSame)
        calendarData = [calendarData dataByDecodingBase64];
      else if ([encoding caseInsensitiveCompare: @"quoted-printable"] == NSOrderedSame)
        calendarData = [calendarData dataByDecodingQuotedPrintableTransferEncoding];

      NS_DURING
        calendar = [iCalCalendar parseSingleFromSource: calendarData];
      NS_HANDLER
        calendar = nil;
      NS_ENDHANDLER

      return calendar;
    }

  // We check if we have at least 2 parts and if one of them is a text/calendar
  parts = [[self bodyStructure] objectForKey: @"parts"];

  if ([parts count] > 1)
    return [self _calendarFromParts: parts  parent: self];

  return nil;
}

//
//
//
- (NSString *) activeSyncRepresentationInContext: (WOContext *) _context
{
  NSData *d, *globalObjId;
  NSArray *attachmentKeys;
  iCalCalendar *calendar;
  NSString *p;
  NSMutableString *s;
  id value;
      
  int preferredBodyType, mimeSupport, mimeTruncation, nativeBodyType;
  uint32_t v;

  preferredBodyType = [[context objectForKey: @"BodyPreferenceType"] intValue];
  mimeSupport = [[context objectForKey: @"MIMESupport"] intValue];
  mimeTruncation = [[context objectForKey: @"MIMETruncation"] intValue];

  s = [NSMutableString string];

  // To - "The value of this element contains one or more e-mail addresses.
  // If there are multiple e-mail addresses, they are separated by commas."
  value = [self _emailAddressesFrom: [[self envelope] to]];
  if (value)
    [s appendFormat: @"<To xmlns=\"Email:\">%@</To>", [value activeSyncRepresentationInContext: context]];

  // From
  value = [self _emailAddressesFrom: [[self envelope] from]];
  if (value)
    [s appendFormat: @"<From xmlns=\"Email:\">%@</From>", [value activeSyncRepresentationInContext: context]];
  
  // Subject
  value = [self decodedSubject];
  if (value)
    {
      [s appendFormat: @"<Subject xmlns=\"Email:\">%@</Subject>", [value activeSyncRepresentationInContext: context]];
      [s appendFormat: @"<ThreadTopic xmlns=\"Email:\">%@</ThreadTopic>", [[self _getNormalizedSubject] activeSyncRepresentationInContext: context]];
    }

  // DateReceived
  value = [self date];
  if (value)
    [s appendFormat: @"<DateReceived xmlns=\"Email:\">%@</DateReceived>", [value activeSyncRepresentationInContext: context]];

  // DisplayTo
  [s appendFormat: @"<DisplayTo xmlns=\"Email:\">%@</DisplayTo>", [[context activeUser] login]];
  
  // Cc - same syntax as the To field
  value = [self _emailAddressesFrom: [[self envelope] cc]];
  if (value)
    [s appendFormat: @"<Cc xmlns=\"Email:\">%@</Cc>", [value activeSyncRepresentationInContext: context]];
    
  // Importance
  v = 0x1;
  value = [[self mailHeaders] objectForKey: @"x-priority"];
  if ([value isKindOfClass: [NSArray class]])
    p = [value lastObject];
  else
    p = value;

  if (p) 
    {
      if ([p hasPrefix: @"1"]) v = 0x2;
      else if ([p hasPrefix: @"2"]) v = 0x2;
      else if ([p hasPrefix: @"4"]) v = 0x0;
      else if ([p hasPrefix: @"5"]) v = 0x0;
    }
  else
    {
      value = [[self mailHeaders] objectForKey: @"importance"];
      if ([value isKindOfClass: [NSArray class]])
        p = [value lastObject];
      else
        p = value;

      if ([p hasPrefix: @"High"]) v = 0x2;
      else if ([p hasPrefix: @"Low"]) v = 0x0;
    }

  [s appendFormat: @"<Importance xmlns=\"Email:\">%d</Importance>", v];
  
  // Read
  [s appendFormat: @"<Read xmlns=\"Email:\">%d</Read>", ([self read] ? 1 : 0)];
  
  // We handle MeetingRequest
  calendar = [self calendarFromIMIPMessage];
 
  if (calendar)
    {
      NSString *method, *className;
      iCalPerson *attendee;
      iCalTimeZone *tz;
      iCalEvent *event;

      iCalPersonPartStat partstat;
      int v;

      event = [[calendar events] lastObject];
      method = [[event parent] method];

      // If we are the organizer, let's pick the attendee based on the From address
      if ([event userIsOrganizer: [context activeUser]])
        attendee = [event findAttendeeWithEmail: [[[[self envelope] from] lastObject] baseEMail]];
      else
        attendee = [event findAttendeeWithEmail: [[[context activeUser] allEmails] objectAtIndex: 0]];

      partstat = [attendee participationStatus];

      // We generate the correct MessageClass
      if ([method isEqualToString: @"REQUEST"])
        className = @"IPM.Schedule.Meeting.Request";
      else if ([method isEqualToString: @"REPLY"])
        {
          switch (partstat)
            {
            case iCalPersonPartStatAccepted:
              className = @"IPM.Schedule.Meeting.Resp.Pos";
              break;
            case iCalPersonPartStatDeclined:
              className = @"IPM.Schedule.Meeting.Resp.Neg";
              break;
            case iCalPersonPartStatTentative:
            case iCalPersonPartStatNeedsAction:
              className = @"IPM.Schedule.Meeting.Resp.Tent";
              break;
            default:
              className = @"IPM.Appointment";
              NSLog(@"unhandled part stat");
            }
        }
      else if ([method isEqualToString: @"COUNTER"])
        className = @"IPM.Schedule.Meeting.Resp.Tent";
      else if ([method isEqualToString: @"CANCEL"])
        className = @"IPM.Schedule.Meeting.Canceled";
      else
        className = @"IPM.Appointment";
      
      [s appendFormat: @"<MessageClass xmlns=\"Email:\">%@</MessageClass>", className];
      
      [s appendString: @"<MeetingRequest xmlns=\"Email:\">"];

      [s appendFormat: @"<AllDayEvent xmlns=\"Email:\">%d</AllDayEvent>", ([event isAllDay] ? 1 : 0)];

      // StartTime -- https://msdn.microsoft.com/en-us/library/ee203365%28v=exchg.80%29.aspx
      if ([event startDate])
        [s appendFormat: @"<StartTime xmlns=\"Email:\">%@</StartTime>", [[event startDate] activeSyncRepresentationInContext: context]];
      
      if ([event timeStampAsDate] && [[event timeStampAsDate] dayOfMonth] > 0 && [[event timeStampAsDate] monthOfYear] > 0)
        [s appendFormat: @"<DTStamp xmlns=\"Email:\">%@</DTStamp>", [[event timeStampAsDate] activeSyncRepresentationInContext: context]];
      else if ([event created])
        [s appendFormat: @"<DTStamp xmlns=\"Email:\">%@</DTStamp>", [[event created] activeSyncRepresentationInContext: context]];
      
      // EndTime -- https://msdn.microsoft.com/en-us/library/ee158628(v=exchg.80).aspx
      if ([event endDate])
        [s appendFormat: @"<EndTime xmlns=\"Email:\">%@</EndTime>", [[event endDate] activeSyncRepresentationInContext: context]];
      
      // FIXME: Single appointment - others are not supported right now
      [s appendFormat: @"<InstanceType xmlns=\"Email:\">%d</InstanceType>", 0];

      // Location
      if ([[event location] length])
        {
          if ([[context objectForKey: @"ASProtocolVersion"] floatValue] >= 16.0)
            [s appendFormat: @"<Location xmlns=\"AirSyncBase:\"><DisplayName>%@</DisplayName></Location>", [[event location] activeSyncRepresentationInContext: context]];
          else
            [s appendFormat: @"<Location xmlns=\"Email:\">%@</Location>", [[event location] activeSyncRepresentationInContext: context]];
        }

      [s appendFormat: @"<Organizer xmlns=\"Email:\">%@</Organizer>", [[[event organizer] mailAddress] activeSyncRepresentationInContext: context]];

      // This will trigger the SendMail command. We set it to no for email invitations as
      // SOGo will send emails when MeetingResponse is called.
      [s appendFormat: @"<ResponseRequested xmlns=\"Email:\">%d</ResponseRequested>", 0];

      // Sensitivity
      if ([[event accessClass] isEqualToString: @"PRIVATE"])
        v = 2;
      if ([[event accessClass] isEqualToString: @"CONFIDENTIAL"])
        v = 3;
      else
        v = 0;

      [s appendFormat: @"<Sensitivity xmlns=\"Email:\">%d</Sensitivity>", v];
      
      [s appendFormat: @"<BusyStatus xmlns=\"Email:\">%d</BusyStatus>", 2];

      // Timezone
      tz = [(iCalDateTime *)[event firstChildWithTag: @"dtstart"] timeZone];
      
      if (!tz)
        tz = [iCalTimeZone timeZoneForName: @"Europe/London"];
      
      [s appendFormat: @"<TimeZone xmlns=\"Email:\">%@</TimeZone>", [tz activeSyncRepresentationInContext: context]];
      

      // We disallow new time proposals
      [s appendFormat: @"<DisallowNewTimeProposal xmlns=\"Email:\">%d</DisallowNewTimeProposal>", 1];
      
      // From http://blogs.msdn.com/b/exchangedev/archive/2011/07/22/working-with-meeting-requests-in-exchange-activesync.aspx:
      //
      // "Clients that need to determine whether the GlobalObjId  element for a meeting request corresponds to an existing Calendar
      // object in the Calendar folder have to convert the GlobalObjId element value to a UID element value to make the comparison."
      //
      globalObjId = [self _computeGlobalObjectIdFromEvent: event];
      [s appendFormat: @"<GlobalObjId xmlns=\"Email:\">%@</GlobalObjId>", [globalObjId activeSyncRepresentationInContext: context]];

      // We set the right message type - we must set AS version to 14.1 for this
      if ([[context objectForKey: @"ASProtocolVersion"] floatValue] >= 14.1)
        [s appendFormat: @"<MeetingMessageType xmlns=\"Email2:\">%d</MeetingMessageType>", 1];

      [s appendString: @"</MeetingRequest>"];

      // ContentClass
      [s appendFormat: @"<ContentClass xmlns=\"Email:\">%@</ContentClass>", @"urn:content-classes:calendarmessage"];
    }
  else
    {
      // MesssageClass and ContentClass
      if ([self _isSigned: [self bodyStructure]])
        [s appendFormat: @"<MessageClass xmlns=\"Email:\">%@</MessageClass>", @"IPM.Note.SMIME.MultipartSigned"];
      else if ([self _isSmimeEncrypted: [self bodyStructure]])
        [s appendFormat: @"<MessageClass xmlns=\"Email:\">%@</MessageClass>", @"IPM.Note.SMIME"];
      else
        [s appendFormat: @"<MessageClass xmlns=\"Email:\">%@</MessageClass>", @"IPM.Note"];

      [s appendFormat: @"<ContentClass xmlns=\"Email:\">%@</ContentClass>", @"urn:content-classes:message"];
    }

  // Reply-To - FIXME
  //NSArray *replyTo = [[message objectForKey: @"envelope"] replyTo];
  //if ([replyTo count])
  //  [s appendFormat: @"<Reply-To xmlns=\"Email:\">%@</Reply-To>", [addressFormatter stringForArray: replyTo]];
  
  // InternetCPID - 65001 == UTF-8, we use this all the time for now.
  //              - 20127 == US-ASCII
  [s appendFormat: @"<InternetCPID xmlns=\"Email:\">%@</InternetCPID>", @"65001"];
          
  // Body - namespace 17
  nativeBodyType = 1;
  d = [self _preferredBodyDataUsingType: preferredBodyType  mimeSupport: mimeSupport  nativeType: &nativeBodyType];

  if (calendar && !d)
    {
      WOApplication *app;
      SOGoAptMailNotification *p;
      NSString *pageName;

      nativeBodyType = 2;

      /* get WOApplication instance */
      app = [WOApplication application];

      /* create page name */
      pageName = [NSString stringWithFormat: @"SOGoAptMail%@", @"Invitation"];
      /* construct message content */
      p = [app pageWithName: pageName inContext: context];
      [p setApt: (iCalEvent *)  [[calendar events] lastObject]];

      if ([[ [[calendar events] lastObject] organizer] cn] && [[[ [[calendar events] lastObject] organizer] cn] length])
        {
          [p setOrganizerName: [[ [[calendar events] lastObject] organizer] cn]];
        }
      else
        {
          [p setOrganizerName: [[SOGoUser userWithLogin: owner] cn]];
        }

      if (preferredBodyType == 1 && nativeBodyType == 2)
        d = [[[p getBody] htmlToText] dataUsingEncoding: NSUTF8StringEncoding];
      else
        {
          preferredBodyType = 2;
          d = [[p getBody] dataUsingEncoding: NSUTF8StringEncoding];
        }

    }
  
  if (d)
    {
      NSMutableData *sanitizedData;
      NSString *content;
      int len, truncated;

      // Outlook fails to decode quoted-printable (see #3082) if lines are not termined by CRLF.
      const char *bytes;
      char *mbytes;
      int mlen;

      len = [d length];
      mlen = 0;

      sanitizedData = [NSMutableData dataWithLength: len*2];

      bytes = [d bytes];
      mbytes = [sanitizedData mutableBytes];

      while (len > 0)
        {
          if (*bytes == '\n' && *(bytes-1) != '\r' && mlen > 0)
            {
              *mbytes = '\r';
              mbytes++;
              mlen++;
            }

          *mbytes = *bytes;
          mbytes++; bytes++;
          len--;
          mlen++;
        }

      [sanitizedData setLength: mlen];

      content = [[NSString alloc] initWithData: sanitizedData  encoding: NSUTF8StringEncoding];

      // FIXME: This is a hack. We should normally avoid doing this as we might get
      // broken encodings. We should rather tell that the data was truncated and expect
      // a ItemOperations call to download the whole base64 encoding multipart.
      //
      // See http://social.msdn.microsoft.com/Forums/en-US/b9944e49-9bc9-4ab8-ba33-a9fc08557c5b/mime-raw-data-in-eas-sync-response?forum=os_exchangeprotocols
      // for an "interesting" discussion around this.
      //
      if (!content)
        content = [[NSString alloc] initWithData: sanitizedData  encoding: NSISOLatin1StringEncoding];
      
      AUTORELEASE(content);
      
      content = [content activeSyncRepresentationInContext: context];
      len = [content length];
      truncated = 0;

      // We handle MIMETruncation
      switch (mimeTruncation)
        {
        case 0:
          {
            content = @"";
            len = 0; truncated = 1;
          }
          break;
        case 1:
          content = [self _truncateContent: content  limit: 4096  truncated: &truncated];
          len = [content length];
          break;
        case 2:
          content = [self _truncateContent: content  limit: 5120  truncated: &truncated];
          len = [content length];
          break;
        case 3:
          content = [self _truncateContent: content  limit: 7168  truncated: &truncated];
          len = [content length];
          break;
        case 4:
          content = [self _truncateContent: content  limit: 10240  truncated: &truncated];
          len = [content length];
          break;
        case 5:
          content = [self _truncateContent: content  limit: 20480  truncated: &truncated];
          len = [content length];
          break;
        case 6:
          content = [self _truncateContent: content  limit: 51200  truncated: &truncated];
          len = [content length];
          break;
        case 7:
          content = [self _truncateContent: content  limit: 102400  truncated: &truncated];
          len = [content length];
          break;
        case 8:
        default:
          truncated = 0;
        }

      if ([[context objectForKey: @"ASProtocolVersion"] isEqualToString: @"2.5"])
        {
          [s appendFormat: @"<Body xmlns=\"Email:\">%@</Body>", content];
          [s appendFormat: @"<BodyTruncated xmlns=\"Email:\">%d</BodyTruncated>", truncated];
        }
      else
        {
          [s appendString: @"<Body xmlns=\"AirSyncBase:\">"];

          // Set the correct type if client requested text/html but we got text/plain.
          // For s/mime mails type is always 4 if mimeSupport is 1 or 2.
          if (preferredBodyType == 2 && nativeBodyType == 1)
             [s appendString: @"<Type>1</Type>"];
          else if (([self _isSigned: [self bodyStructure]] ||
                    [self _isSmimeEncrypted: [self bodyStructure]] ||
                    [self _isPGP: [self bodyStructure]]) && mimeSupport > 0)
             [s appendString: @"<Type>4</Type>"];
          else
             [s appendFormat: @"<Type>%d</Type>", preferredBodyType];

          if ([[context objectForKey: @"MultiPartsLen"] isKindOfClass: [NSArray class]])
            {
              [[context objectForKey: @"MultiPartsLen"]  addObject: [NSNumber numberWithInteger: [sanitizedData length]]];
              [[context objectForKey: @"MultiParts"]  appendData: sanitizedData];

              [s appendFormat: @"<EstimatedDataSize>%d</EstimatedDataSize>", len];
              [s appendFormat: @"<Part xmlns=\"ItemOperations:\">%d</Part>", [[context objectForKey: @"MultiPartsLen"] count]];
            }
          else
            {
              [s appendFormat: @"<Truncated>%d</Truncated>", truncated];
              [s appendFormat: @"<Preview></Preview>"];
              [s appendFormat: @"<Data>%@</Data>", content];
              [s appendFormat: @"<EstimatedDataSize>%d</EstimatedDataSize>", len];
            }

          [s appendString: @"</Body>"];
       }
    }

  // Attachments -namespace 16
  attachmentKeys = [self fetchFileAttachmentKeys];

  if ([attachmentKeys count] && !([self _isSigned: [self bodyStructure]]))
    {
      int i;

      if ([[context objectForKey: @"ASProtocolVersion"] isEqualToString: @"2.5"])
        [s appendString: @"<Attachments xmlns=\"Email:\">"];
      else
        [s appendString: @"<Attachments xmlns=\"AirSyncBase:\">"];

      for (i = 0; i < [attachmentKeys count]; i++)
        {
          value = [attachmentKeys objectAtIndex: i];

          [s appendString: @"<Attachment>"];
          [s appendFormat: @"<DisplayName>%@</DisplayName>", [[value objectForKey: @"filename"] activeSyncRepresentationInContext: context]];

          // FileReference must be a unique identifier across the whole store. We use the following structure:
          // mail/<foldername>/<message UID/<pathofpart>
          // mail/INBOX/2          
          if ([[context objectForKey: @"ASProtocolVersion"] isEqualToString: @"2.5"])
            [s appendFormat: @"<AttName>mail/%@/%@/%@</AttName>", [[[self container] relativeImap4Name] stringByEscapingURL], [self nameInContainer], [value objectForKey: @"path"]];
          else
            [s appendFormat: @"<FileReference>mail/%@/%@/%@</FileReference>", [[[self container] relativeImap4Name] stringByEscapingURL], [self nameInContainer], [value objectForKey: @"path"]];

          if ([[context objectForKey: @"ASProtocolVersion"] isEqualToString: @"2.5"])
            {
              [s appendFormat: @"<AttMethod>%d</AttMethod>", 1];
              [s appendFormat: @"<AttSize>%d</AttSize>", [[value objectForKey: @"size"] intValue]];
            }
          else
            {
              if ([[value objectForKey: @"bodyId"] length])
                {
                  [s appendFormat: @"<ContentId>%@</ContentId>", [[[value objectForKey: @"bodyId"] stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @"<>"]] activeSyncRepresentationInContext: context]];
                  [s appendFormat: @"<IsInline>%d</IsInline>", 1];
                }

              [s appendFormat: @"<Method>%d</Method>", 1]; // See: http://msdn.microsoft.com/en-us/library/ee160322(v=exchg.80).aspx
              [s appendFormat: @"<EstimatedDataSize>%d</EstimatedDataSize>", [[value objectForKey: @"size"] intValue]];
              //[s appendFormat: @"<IsInline>%d</IsInline>", 1];
            }
          [s appendString: @"</Attachment>"];
        }

      [s appendString: @"</Attachments>"];
    }
  
  // Flags
  [s appendString: @"<Flag xmlns=\"Email:\">"];
  [s appendFormat: @"<FlagStatus>%d</FlagStatus>", ([self flagged] ? 2 : 0)];
  [s appendString: @"</Flag>"];


  // Categroies/Labels
  NSEnumerator *categories;
  categories = [[[self fetchCoreInfos] objectForKey: @"flags"] objectEnumerator];

  if (categories)
    {
      NSString *currentFlag;
      NSDictionary *v;

      v = [[[context activeUser] userDefaults] mailLabelsColors];

      [s appendFormat: @"<Categories xmlns=\"Email:\">"];
      while ((currentFlag = [categories nextObject]))
        {
          if ([[v objectForKey: currentFlag] objectAtIndex:0])
            [s appendFormat: @"<Category>%@</Category>", [[[v objectForKey: currentFlag] objectAtIndex:0] activeSyncRepresentationInContext: context]];
        }
      [s appendFormat: @"</Categories>"];
    }
  
    if ([[context objectForKey: @"ASProtocolVersion"] floatValue] >= 14.0)
    {
      id value;
      NSString *reference;

      value = [[self mailHeaders] objectForKey: @"references"];

      if ([value isKindOfClass: [NSArray class]])
         reference = [[[value objectAtIndex: 0] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] objectAtIndex: 0];
      else
         reference = [[value componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] objectAtIndex: 0];

      if ([reference length] > 0)
        [s appendFormat: @"<ConversationId xmlns=\"Email2:\">%@</ConversationId>", [[reference dataUsingEncoding: NSUTF8StringEncoding] activeSyncRepresentationInContext: context]];
      else if ([[self inReplyTo] length] > 0)
        [s appendFormat: @"<ConversationId xmlns=\"Email2:\">%@</ConversationId>", [[[self inReplyTo] dataUsingEncoding: NSUTF8StringEncoding] activeSyncRepresentationInContext: context]];
      else if ([[self messageId] length] > 0)
        [s appendFormat: @"<ConversationId xmlns=\"Email2:\">%@</ConversationId>", [[[self messageId] dataUsingEncoding: NSUTF8StringEncoding] activeSyncRepresentationInContext: context]];

      if ([self replied])
        [s appendFormat: @"<LastVerbExecuted xmlns=\"Email2:\">%d</LastVerbExecuted>", 1];
      else if ([self forwarded])
        [s appendFormat: @"<LastVerbExecuted xmlns=\"Email2:\">%d</LastVerbExecuted>", 3];
      else
        [s appendFormat: @"<LastVerbExecuted xmlns=\"Email2:\">%d</LastVerbExecuted>", 0];
    }

  // FIXME - support these in the future
  //[s appendString: @"<ConversationIndex xmlns=\"Email2:\">zot=</ConversationIndex>"];

  
  // NativeBodyType -- http://msdn.microsoft.com/en-us/library/ee218276(v=exchg.80).aspx
  // This is a required child element.
  // 1 -> plain/text, 2 -> HTML and 3 -> RTF
  if (nativeBodyType == 4)
    nativeBodyType = 1;

  [s appendFormat: @"<NativeBodyType xmlns=\"AirSyncBase:\">%d</NativeBodyType>", nativeBodyType];
  
  return s;
}

//
//
//
// Exemple for a message being marked as read:
//
//  <Change>
//   <ServerId>607</ServerId>
//   <ApplicationData>
//    <Read xmlns="Email:">1</Read>
//   </ApplicationData>
//  </Change>
// </Commands>
//
- (void) takeActiveSyncValues: (NSDictionary *) theValues
                    inContext: (WOContext *) _context
{
  id o;

  if ((o = [theValues objectForKey: @"Flag"]))
    {
      // We must handle empty flags -> {Flag = ""; } - some ActiveSync clients, like the HTC Desire
      // will send an empty Flag message when "unflagging" a mail.
      if (([o isKindOfClass: [NSMutableDictionary class]]))
        {
          if ((o = [o objectForKey: @"FlagStatus"]))
            {
              // 0 = The flag is cleared.
              // 1 = The status is set to complete.
              // 2 = The status is set to active.
              if (([o isEqualToString: @"2"]))
                [self addFlags: @"\\Flagged"];
              else
                [self removeFlags: @"\\Flagged"];
            }
        }
      else
        [self removeFlags: @"\\Flagged"]; 
    }
  
  if ((o = [theValues objectForKey: @"Read"]))
    {
      if ([o intValue])
        [self addFlags: @"seen"];
      else
        [self removeFlags: @"seen"];;
    }

  if ((o = [theValues objectForKey: @"Categories"]))
    {
      NSEnumerator *categories;
      NSString *currentFlag;
      NSDictionary *v;

      v = [[[context activeUser] userDefaults] mailLabelsColors];

      // add categories/labels sent from client
      if ([o isKindOfClass: [NSArray class]])
        {
          NSEnumerator *enumerator;
          NSMutableArray *labels;
          NSEnumerator *flags;
          id key;

          labels = [NSMutableArray array];

          enumerator = [v keyEnumerator];
          flags = [o objectEnumerator];

          while ((currentFlag = [flags nextObject]))
            {
              while ((key = [enumerator nextObject]))
                {
                  if (([currentFlag isEqualToString:[[v objectForKey:key] objectAtIndex:0]]))
                    {
                      [labels addObject: key];
                      break;
                    }
                }
            }

          [self addFlags: [labels componentsJoinedByString: @" "]];
        }

      categories = [[[self fetchCoreInfos] objectForKey: @"flags"] objectEnumerator];

      // remove all categories/labels from server which were not it the list sent from client
      if (categories)
        {
          while ((currentFlag = [categories nextObject]))
            {
              // only deal with lables and don't touch flags like seen and flagged
              if (([v objectForKey: currentFlag]))
                {
                  if (![o isKindOfClass: [NSArray class]])
                    {
                      [self removeFlags: currentFlag];
                    }
                  else if (([o indexOfObject: [[v objectForKey:currentFlag] objectAtIndex:0]] == NSNotFound))
                    {
                      [self removeFlags: currentFlag];
                    }
                }
            }
        }
    }
}

- (NSString *) storeMail: (NSDictionary *) theValues
                inBuffer: (NSMutableString *) theBuffer
               inContext: (WOContext *) _context
{
  NSString *dateReceived, *folder, *s, *serverId, *messageId;
  NGMimeMessageGenerator *generator;
  NGMimeMessage *draftMessage;
  NGMimeBodyPart *bodyPart;
  NGMimeMultipartBody *body;
  NSDictionary *identity;
  NGMutableHashMap *map;
  NGImap4Client *client;
  NSData *message_data;
  NSArray *attachmentKeys;

  id o, a, result, attachments;
  int bodyType, i;

  identity = [[context activeUser] primaryIdentity];
  message_data = nil;
  bodyType = 1;

  if ((o = [[theValues objectForKey: @"Body"] objectForKey: @"Type"]))
    bodyType = [o intValue];

  if (bodyType == 4)
    {
      s = [[theValues objectForKey: @"Body"] objectForKey: @"Data"];
      message_data = [s dataUsingEncoding: NSUTF8StringEncoding];
    }

  if (bodyType == 1 || bodyType == 2)
    {
      map = [[[NGMutableHashMap alloc] initWithCapacity: 1] autorelease];

      [map setObject: [NSString stringWithFormat: @"%@ <%@>", [identity objectForKey: @"fullName"], [identity objectForKey: @"email"]]  forKey: @"from"];

      if ((o = [theValues objectForKey: @"To"]))
          [map setObject: o  forKey: @"to"];

      if ((o = [theValues objectForKey: @"Cc"]))
          [map setObject: o  forKey: @"cc"];

      if ((o = [theValues objectForKey: @"Bcc"]))
          [map setObject: o  forKey: @"bcc"];

      if ((o = [theValues objectForKey: @"Reply-To"]))
          [map setObject: o  forKey: @"Reply-To"];

      if ((o = [theValues objectForKey: @"Subject"]))
          [map setObject: o  forKey: @"subject"];

      o = [[theValues objectForKey: @"DateReceived"] calendarDate];

      if (!o)
        o = [NSCalendarDate date];

#if GNUSTEP_BASE_MINOR_VERSION < 21
      dateReceived = [o descriptionWithCalendarFormat: @"%a, %d %b %Y %H:%M:%S %z"
                                             timeZone: [NSTimeZone timeZoneWithName: @"GMT"]
                                               locale: nil];
#else
      dateReceived = [o descriptionWithCalendarFormat: @"%a, %d %b %Y %H:%M:%S %z"
                                             timeZone: [NSTimeZone timeZoneWithName: @"GMT"]
                                               locale: [NSDictionary dictionaryWithObjectsAndKeys:
                                                                        [NSArray arrayWithObjects: @"Jan", @"Feb", @"Mar", @"Apr",
                                                                                 @"May", @"Jun", @"Jul", @"Aug",
                                                                                 @"Sep", @"Oct", @"Nov", @"Dec", nil],
                                                                     @"NSShortMonthNameArray",
                                                                        [NSArray arrayWithObjects: @"Sun", @"Mon", @"Tue", @"Wed", @"Thu",
                                                                                 @"Fri", @"Sat", nil],
                                                                     @"NSShortWeekDayNameArray",
                                                                     nil]];
#endif

      [map setObject: dateReceived forKey: @"date"];

      messageId = [NSString generateMessageID];
      [map setObject: messageId forKey: @"message-id"];

      attachmentKeys = [self fetchFileAttachmentKeys];

      if ((attachments = [theValues objectForKey: @"Attachments"]) || [attachmentKeys count])
        {
          [map setObject: @"multipart/mixed" forKey: @"content-type"];
          draftMessage = [[[NGMimeMessage alloc] initWithHeader: map] autorelease];
          body = [[[NGMimeMultipartBody alloc] initWithPart: draftMessage] autorelease];

          map = [[[NGMutableHashMap alloc] initWithCapacity: 1] autorelease];

          [map setObject: (bodyType == 1 ? @"text/plain; charset=utf-8" : @"text/html; charset=utf-8")
                  forKey: @"content-type"];
          [map setObject: @"quoted-printable" forKey: @"content-transfer-encoding"];

          bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];

          [bodyPart setBody: [[NSString stringWithFormat: @"%@", [[theValues objectForKey: @"Body"] objectForKey: @"Data"] ] dataUsingEncoding: NSUTF8StringEncoding]];

          [body addBodyPart: bodyPart];

           // Add attachments from the original mail - skip deletions
           if ([attachmentKeys count])
             {
               id currentAttachment;
               NGHashMap *response;
               NSData *bodydata;
               NSArray *paths;
               NGMimeFileData *fdata;
               int i, ii;
               BOOL found;

               paths = [attachmentKeys keysWithFormat: @"BODY[%{path}]"];
               response = [[self fetchParts: paths] objectForKey: @"RawResponse"];

               for (i = 0; i < [attachmentKeys count]; i++)
                 {
                   currentAttachment = [attachmentKeys objectAtIndex: i];
                   found = NO;
                   for (ii = 0; ii < [attachments count]; ii++)
                     {
                       // no ClientId means its a deletio
                       if (![[attachments objectAtIndex: ii] objectForKey: @"ClientId"] &&
                           [[[[attachments objectAtIndex: ii] objectForKey: @"FileReference"] lastPathComponent] isEqualToString: [currentAttachment objectForKey: @"path"]])
                         {
                           found = YES;
                           break;
                         }
                      }

                   // skip deletions
                   if (found)
                     continue;

                   bodydata = [[[response objectForKey: @"fetch"] objectForKey: [NSString stringWithFormat: @"body[%@]", [currentAttachment objectForKey: @"path"]]] valueForKey: @"data"];

                   map = [[[NGMutableHashMap alloc] initWithCapacity: 1] autorelease];
                   [map setObject: [currentAttachment objectForKey: @"mimetype"] forKey: @"content-type"];
                   [map setObject: [currentAttachment objectForKey: @"encoding"] forKey: @"content-transfer-encoding"];
                   [map addObject: [NSString stringWithFormat: @"attachment; filename=\"%@\"", [currentAttachment objectForKey: @"filename"]] forKey: @"content-disposition"];
                   bodyPart = [[[NGMimeBodyPart alloc] initWithHeader: map] autorelease];

                   fdata = [[NGMimeFileData alloc] initWithBytes:[bodydata bytes]  length:[bodydata length]];
                   [bodyPart setBody: fdata];
                   RELEASE(fdata);
                   [body addBodyPart: bodyPart];
                 }
              }

          // add new attachments
          for (i = 0; i < [attachments count]; i++)
            {

               map = [[[NGMutableHashMap alloc] initWithCapacity: 1] autorelease];
               a = [attachments objectAtIndex: i];

               // no ClientId means its a deletion
               if (![a objectForKey: @"ClientId"])
                 continue;

               [map setObject: @"application/octet-stream" forKey: @"content-type"]; // FIXME ?? can we guess the right content-type
               [map setObject: @"base64" forKey: @"content-transfer-encoding"];
               [map setObject: [NSString stringWithFormat: @"attachment; filename=\"%@\"", [a objectForKey: @"DisplayName"]] forKey: @"content-disposition"];

               bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];
               [bodyPart setBody: [[a objectForKey: @"Content"] stringByDecodingBase64]];
               [body addBodyPart: bodyPart];
            }


          [draftMessage setBody: body];
        }
      else
        {
          [map setObject: (bodyType == 1 ? @"text/plain; charset=utf-8" : @"text/html; charset=utf-8")
                  forKey: @"content-type"];
          [map setObject: @"quoted-printable" forKey: @"content-transfer-encoding"];

          draftMessage = [[[NGMimeMessage alloc] initWithHeader: map] autorelease];

          [draftMessage setBody: [[NSString stringWithFormat: @"%@", [[theValues objectForKey: @"Body"] objectForKey: @"Data"] ] dataUsingEncoding: NSUTF8StringEncoding]];
        }

      generator = [[[NGMimeMessageGenerator alloc] init] autorelease];
      message_data = [generator generateMimeFromPart: draftMessage];
    }

  if (message_data)
    {
      client = [[self imap4Connection] client];

      if (![imap4 doesMailboxExistAtURL: [container imap4URL]])
        {
          [[self imap4Connection] createMailbox: [[self imap4Connection] imap4FolderNameForURL: [container imap4URL]]
                                          atURL: [[self mailAccountFolder] imap4URL]];
          [imap4 flushFolderHierarchyCache];
        }

      folder = [imap4 imap4FolderNameForURL: [container imap4URL]];

      result = [client append: message_data
                     toFolder: folder
                    withFlags: [NSArray arrayWithObjects: @"draft", nil]];

      serverId = [NSString stringWithFormat: @"%d", [self IMAP4IDFromAppendResult: result]];

      [theBuffer appendString: @"<ApplicationData>"];
      [theBuffer appendFormat: @"<ConversationId xmlns=\"Email2:\">%@</ConversationId>", [[messageId dataUsingEncoding: NSUTF8StringEncoding] activeSyncRepresentationInContext: context]];

      if ([attachments count])
        {
          [theBuffer appendString: @"<Attachments xmlns=\"AirSyncBase:\">"];

          for (i = 0; i < [attachments count]; i++)
            {
              a = [attachments objectAtIndex: i];

              [theBuffer appendString: @"<Attachment>"];
              [theBuffer appendFormat: @"<ClientId xmlns=\"AirSyncBase:\">%@</ClientId>", [a objectForKey: @"ClientId"]];
              [theBuffer appendFormat: @"<FileReference xmlns=\"AirSyncBase:\">mail/%@/%@/%d</FileReference>", [[[self container] relativeImap4Name] stringByEscapingURL], serverId, i+2];
              [theBuffer appendString: @"</Attachment>"];
            }

            [theBuffer appendString: @"</Attachments>"];
          }

      [theBuffer appendString: @"</ApplicationData>"];

      if ([[result objectForKey: @"result"] boolValue])
        return serverId;
    }

  return nil;
}


@end
