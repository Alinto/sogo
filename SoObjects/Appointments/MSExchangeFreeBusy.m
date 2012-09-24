/* MSExchangeFreeBusy.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc.
 *
 * Author: Francis Lachapelle <flachapelle@inverse.ca>
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NSObject+Logs.h>

#import <SaxObjC/SaxObjC.h>
#import <SaxObjC/SaxMethodCallHandler.h>
#import <SaxObjC/SaxObjectDecoder.h>
#import <SaxObjC/SaxXMLReaderFactory.h>

#import <curl/curl.h>

#import <SOGo/SOGoSource.h>

#import "MSExchangeFreeBusySOAPRequest.h"
#import "MSExchangeFreeBusy.h"

size_t curl_body_function_freebusy(void *ptr, size_t size, size_t nmemb, void *inSelf)
{
  return [(MSExchangeFreeBusy *)inSelf curlWritePtr:ptr size:size number:nmemb];
}

@implementation MSExchangeFreeBusy

- (id) init
{
  if ((self = [super init]))
    {
      curlBody = [[NSMutableData alloc] init];
    }

  return self;
}

- (void) dealloc
{
  [curlBody release];
  [super dealloc];
}

- (size_t) curlWritePtr:(void *)inPtr
                   size:(size_t)inSize
                 number:(size_t)inNumber
{
  size_t written = inSize*inNumber;
  NSData *data = [NSData dataWithBytes:inPtr length:written];
  [curlBody appendData: data];
  
  return written;
}

/**
 * Fetch the user availability by sending a SOAP request to a MS Exchange server (EWS).
 * @param startDate the beginning of the covered period
 * @param endDate the ending of the covered period
 * @param email the address of the user to query
 * @param source the SOGo source of the user
 * @param context the current WO context
 * @return an array of dictionaries containing the start and end dates of each busy period
 * @see <http://msdn.microsoft.com/en-us/library/aa563800(v=EXCHG.140).aspx>
 */
- (NSArray *) fetchFreeBusyInfosFrom: (NSCalendarDate *) startDate
                                  to: (NSCalendarDate *) endDate
                            forEmail: (NSString *) email
                            inSource: (NSObject <SOGoDNSource> *) source
                           inContext: (WOContext *) context
{
  static id<NSObject,SaxXMLReader> parser = nil;
  static SaxObjectDecoder *sax = nil;
  
  MSExchangeFreeBusySOAPRequest *soapRequest;
  MSExchangeFreeBusyResponse *freeBusyResponse;
  NSString *rawRequest, *url, *body, *hostname, *httpauth, *authname, *password;
  NSArray *infos = nil;
  NSDictionary *root;
  
  CURL *curl;
  struct curl_slist *headerlist=NULL;
  CURLcode rc;
  char error[CURL_ERROR_SIZE];

  // Construct SOAP GetUserAvailabilityRequest from .wo template
  soapRequest = [[WOApplication application] pageWithName: @"MSExchangeFreeBusySOAPRequest"
                                                inContext: context];
  [soapRequest setAddress: email
                     from: startDate
                       to: endDate];
  rawRequest = [[soapRequest generateResponse] contentAsString];

  if ([rawRequest length])
    {
      // Prepare HTTPS post using libcurl
      curl_global_init(CURL_GLOBAL_SSL);
      curl = curl_easy_init();
      headerlist = curl_slist_append(headerlist, "Content-Type: text/xml; charset=utf-8");
      if (curl)
        {
          hostname = [source MSExchangeHostname];
          authname = [source lookupLoginByDN: [source bindDN]];
          password = [source bindPassword];
          error[0] = 0;
          if ([authname length] && [password length])
            {
              httpauth = [NSString stringWithFormat: @"%@:%@", authname, password];
              curl_easy_setopt(curl, CURLOPT_USERPWD, [httpauth UTF8String]);
              curl_easy_setopt(curl, CURLOPT_HTTPAUTH, CURLAUTH_NTLM);
            }
          url = [NSString stringWithFormat: @"https://%@/ews/Exchange.asmx", hostname];
          curl_easy_setopt(curl, CURLOPT_URL, [url UTF8String]);
          curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headerlist);
          curl_easy_setopt(curl, CURLOPT_POSTFIELDS, [rawRequest UTF8String]);
          //curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, curlHeaderFunction);
          //curl_easy_setopt(curl, CURLOPT_HEADER, 1);
          curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
          curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
          curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_body_function_freebusy);
          curl_easy_setopt(curl, CURLOPT_WRITEDATA, self);
          curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, &error);

          // Perform SOAP request
          rc = curl_easy_perform(curl);
          if (rc != 0)
            [self errorWithFormat: @"CURL error while accessing %@ (%d): ", url, rc, [NSString stringWithCString: error]];
          curl_easy_cleanup(curl);
          curl_slist_free_all(headerlist);
        
          if ([curlBody length])
            {
              // Parse SOAP response
              if (parser == nil)
                {
                  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
                             createXMLReaderForMimeType:@"text/xml"];
                  [parser retain];
                }            
              if (sax == nil && parser != nil)
                {
                  sax = [[SaxObjectDecoder alloc] initWithMappingAtPath:@"./MSExchangeFreeBusySOAPResponseMap.plist"];
                  [parser setContentHandler:sax];
                  //[parser setErrorHandler:sax];
                }
              
              body =  [[NSString alloc] initWithData:curlBody encoding:NSASCIIStringEncoding];
              [body autorelease];
            
              [parser parseFromSource: body];
              root = [sax rootObject];
              freeBusyResponse = [[root objectForKey: @"Body"] objectForKey: @"GetUserAvailabilityResponse"];

              // Extract busy periods
              infos = [[freeBusyResponse view] infosFrom: startDate to: endDate];
            }
        }
    }

  return infos;
}

@end


@implementation MSExchangeFreeBusyResponse

- (id) init
{
  if ((self = [super init]))
    {
      view = nil;
    }

  return self;
}

- (void) dealloc
{
  [view release];
  [super dealloc];
}

- (MSExchangeFreeBusyView *) view
{
  return self->view;
}

- (void) setFreeBusyResponseArray: (NSDictionary *) _value
{
  NSString *responseCode;
  NSArray *responses;
  NSDictionary *response;

  view = nil;
  responses = (NSArray *) [_value objectForKey: @"responses"];
  
  if ([responses count] != 1)
    {
      [self errorWithFormat: @"unexpected number of responses (%i) from SOAP request", [responses count]];
    }
  else
    {
      response = [responses objectAtIndex: 0];
      responseCode = [[response objectForKey: @"ResponseMessage"] objectForKey: @"ResponseCode"];
      if ([responseCode compare: @"NoError"] == NSOrderedSame)
        {
          view = [response objectForKey: @"FreeBusyView"];
          [view retain];
        }
    }
  
  [self logWithFormat: @"SOAP Response: %@", self->view];
}

@end

@implementation MSExchangeFreeBusyView

- (id) init
{
  if ((self = [super init]))
    {
      freeBusyViewType = nil;
      mergedFreeBusy = nil;
    }

  return self;
}

- (void) dealloc
{
  [freeBusyViewType release];
  [mergedFreeBusy release];
  [super dealloc];
}

- (void) setFreeBusyViewType: (NSString *) _value
{
  ASSIGN(freeBusyViewType, _value);
}

- (void) setMergedFreeBusy: (NSString *) _value
{
  ASSIGN(mergedFreeBusy, _value);
}

/**
 * Parse the "DetailedMerged" representation of the freebusy information and 
 * extract the busy periods.
 * @param startDate the beginning of the covered period
 * @param endDate the ending of the covered period
 * @return an array of dictionaries containing the start and end dates of each busy period
 * @see <http://msdn.microsoft.com/en-us/library/aa565898(v=EXCHG.140).aspx>
 */
- (NSArray *) infosFrom: (NSCalendarDate *) startDate
                     to: (NSCalendarDate *) endDate
{
  NSMutableArray *infos;
  NSCalendarDate *currentDate, *currentStartDate, *currentEndDate;
  unsigned int count;

  infos = [NSMutableArray array];
  currentStartDate = nil;
  currentDate = startDate;
  count = 0;

  while (([currentDate compare: endDate] == NSOrderedAscending ||
          [currentDate compare: endDate] == NSOrderedSame) &&
         [mergedFreeBusy length] > count)
    {
      switch ([mergedFreeBusy characterAtIndex: count])
        {
        case '0': // Free
          if (currentStartDate)
            {
              currentEndDate = currentDate;
              [infos addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool: YES], @"c_isopaque",
                                                  currentStartDate, @"startDate",
                                                  currentEndDate, @"endDate", nil]];
              [self debugWithFormat: @"Busy period from %@ to %@", currentStartDate, currentEndDate];
              currentStartDate = nil;
            }
          break;
          
        case '1': // Tentative
        case '2': // Busy
        case '3': // Out of Office
          if (currentStartDate == nil)
            currentStartDate = currentDate;
          break;
        }

      count++;
      currentDate = [currentDate dateByAddingYears: 0 months: 0 days: 0
                                             hours: 0 minutes: 15 seconds: 0];
    }

  if (currentStartDate)
    {
      currentEndDate = currentDate;
      [infos addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithBool: YES], @"c_isopaque",
                                      currentStartDate, @"startDate",
                                      currentEndDate, @"endDate", nil]];
      [self debugWithFormat: @"Busy period from %@ to %@", currentStartDate, currentEndDate];
    }

  return infos;
}

- (NSString *) description
{
  NSMutableString *s;

  s = [NSMutableString stringWithCapacity: 64];
  [s appendFormat:@"<0x%08X[%@]:", self, NSStringFromClass([self class])];
  if (freeBusyViewType)
    [s appendFormat:@" freeBusyViewType='%@'", freeBusyViewType];
  if (mergedFreeBusy)
    [s appendFormat:@" mergedFreeBusy='%@'", mergedFreeBusy];
  [s appendString:@">"];
  
  return s;
}

@end
