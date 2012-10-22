/* WORequest+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2010 Inverse inc.
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

#import <NGObjWeb/SoObjectRequestHandler.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WEClientCapabilities.h>
#import <NGObjWeb/WORequest+So.h>

#import <DOM/DOMProtocols.h>

#import "WORequest+SOGo.h"

@implementation WORequest (SOGoSOPEUtilities)

- (BOOL) handledByDefaultHandler
{
#warning this should be changed someday
  return ![[self requestHandlerKey] isEqualToString:@"dav"];
}

- (NSArray *) _propertiesOfElement: (id <DOMElement>) startElement
			  underTag: (NSString *) tag
{
  id <DOMNodeList> list;
  id <DOMElement> tagElement;
  NSObject <DOMNode> *currentNode;
  NSMutableArray *properties;
  unsigned int count, max;

  properties = nil;

  list = [startElement getElementsByTagName: tag];
  if ([list length])
    {
      tagElement = [list objectAtIndex: 0];
      list = [tagElement getElementsByTagName: @"prop"];
      if ([list length])
	{
	  tagElement = [list objectAtIndex: 0];
	  properties = [NSMutableArray array];
	  list = [tagElement childNodes];
	  max = [list length];
	  for (count = 0; count < max; count++)
	    {
	      currentNode = [list objectAtIndex: count];
	      if ([currentNode conformsToProtocol: @protocol (DOMElement)])
		[properties addObject: currentNode];
	    }
	}
    }

  return properties;
}

- (NSDictionary *) davPatchedPropertiesWithTopTag: (NSString *) topTag
{
  NSMutableDictionary *patchedProperties;
  NSArray *props;
  id <DOMDocument> element;
  id <DOMElement> startElement;
  NSObject <DOMNodeList> *list;

  patchedProperties = nil;
  if (!topTag)
    topTag = @"propertyupdate";
  element = [self contentAsDOMDocument];
  list = [element getElementsByTagName: topTag];
  if ([list length])
    {
      startElement = [list objectAtIndex: 0];
      patchedProperties = [NSMutableDictionary dictionary];
      props = [self _propertiesOfElement: startElement
		    underTag: @"set"];
      if (props)
	[patchedProperties setObject: props forKey: @"set"];
      props = [self _propertiesOfElement: startElement
		    underTag: @"remove"];
      if (props)
	[patchedProperties setObject: props forKey: @"remove"];
    }

  return patchedProperties;
}

/* So many different DAV libraries... */
- (BOOL) isAppleDAVWithSubstring: (NSString *) osSubstring
{
  WEClientCapabilities *cc;
  BOOL rc;
  NSRange r;

  cc = [self clientCapabilities];
  if ([[cc userAgentType] isEqualToString: @"AppleDAVAccess"])
    {
      r = [[cc userAgent] rangeOfString: osSubstring];
      rc = (r.location != NSNotFound);
    }
  else
    rc = NO;

  return rc;
}

- (BOOL) isIPhone
{
  return [self isAppleDAVWithSubstring: @"iPhone/"]
	 || [self isAppleDAVWithSubstring: @"iOS/"];
}

- (BOOL) isICal
{
  return ([self isAppleDAVWithSubstring: @"Mac OS X/10."]
          || [self isAppleDAVWithSubstring: @"CoreDAV/"]);
}

//
// CalendarStore/5.0.1 (1139.14); iCal/5.0.1 (1547.4); Mac OS X/10.7.2 (11C74)
// CalendarStore/5.0.3 (1204.1); iCal/5.0.3 (1605.3); Mac OS X/10.7.4 (11E53)
// Mac OS X/10.8 (12A269) Calendar/1639
// Mac OS X/10.8 (12A269) CalendarAgent/47
// Mac OS X/10.8.1 (12B19) CalendarAgent/47
//
- (BOOL) isICal4
{
  return ([self isAppleDAVWithSubstring: @"iCal/4."]
          || [self isAppleDAVWithSubstring: @"iCal/5."]
          || [self isAppleDAVWithSubstring: @"CoreDAV/"]
          || [self isAppleDAVWithSubstring: @"Calendar/"]
          || [self isAppleDAVWithSubstring: @"CalendarAgent/"]);
}


//
// For 10.7, we see:
//
// AddressBook/6.1 (1062) CardDAVPlugin/196 CFNetwork/520.2.5 Mac_OS_X/10.7.2 (11C74)
// AddressBook/6.1.2 (1090) CardDAVPlugin/200 CFNetwork/520.4.3 Mac_OS_X/10.7.4 (11E53)
//
// For 10.8, we see:
//
// Mac OS X/10.8 (12A269) AddressBook/1143
// Mac OS X/10.8.1 (12B19) AddressBook/1143
//
- (BOOL) isMacOSXAddressBookApp
{
  WEClientCapabilities *cc;
  BOOL b;

  cc = [self clientCapabilities];

  b =  ([[cc userAgent] rangeOfString: @"CFNetwork"].location != NSNotFound
        && ([[cc userAgent] rangeOfString: @"Darwin"].location != NSNotFound
            || [[cc userAgent] rangeOfString: @"Mac OS X"].location != NSNotFound)
        && [[cc userAgent] rangeOfString: @"AddressBook"].location != NSNotFound);

  return b;
}

- (BOOL) isIPhoneAddressBookApp
{
  WEClientCapabilities *cc;

  cc = [self clientCapabilities];

  return ([[cc userAgent] rangeOfString: @"DataAccess/1.0"].location != NSNotFound ||
          [[cc userAgent] rangeOfString: @"dataaccessd/1.0"].location != NSNotFound); // Seen on iOS 5.0.1 on iPad
}

- (BOOL) isAndroid
{
  WEClientCapabilities *cc;

  cc = [self clientCapabilities];

  // CardDAV-Sync (Android) (like iOS/5.0.1 (9A405) dataaccessd/1.0) gzip 
  return ([[cc userAgent] rangeOfString: @"Android"].location != NSNotFound);
}


@end
