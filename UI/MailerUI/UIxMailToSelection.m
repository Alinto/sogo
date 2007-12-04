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

#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGMail/NGMailAddress.h>
#import <NGMail/NGMailAddressParser.h>

#import <SOGoUI/UIxComponent.h>

/*
  UIxMailToSelection
  
  Select a set of address headers for composing an email.
  
  Bindings:
  to   - array of strings suitable for placement in a To: header
  cc   - array of strings suitable for placement in a Cc: header
  bcc  - array of strings suitable for placement in a Bcc: header
  
  Sample:
  <var:component className="UIxMailToSelection"
  to="to"
  cc="cc"
  bcc="bcc"
  />
*/

@class NSArray;

@interface UIxMailToSelection : UIxComponent
{
  NSArray *to;
  NSArray *cc;
  NSArray *bcc;
  id      item;
  id      address;
  NSArray *addressList;
  int     currentIndex;
}

- (void) setTo: (NSArray *) _to;
- (NSArray *) to;
- (void) setCc: (NSArray *) _cc;
- (NSArray *) cc;
- (void) setBcc: (NSArray *) _bcc;
- (NSArray *) bcc;

- (void) getAddressesFromFormValues: (NSDictionary *) _dict;
- (NSString *) getIndexFromIdentifier: (NSString *) _identifier;

@end

@implementation UIxMailToSelection

static NSArray *headers = nil;

+ (void) initialize
{
  static BOOL didInit = NO;
  if (!didInit)
    {
      didInit = YES;
      headers = [[NSArray alloc] initWithObjects: @"to", @"cc", @"bcc", nil];
    }
}

- (id) init
{
  if ((self = [super init]))
    currentIndex = -1;

  return self;
}

- (void) dealloc
{
  [to          release];
  [cc          release];
  [bcc         release];
  [item        release];
  [address     release];
  [addressList release];
  [super dealloc];
}

/* accessors */

- (void) setTo: (NSArray *) _to
{
  ASSIGN (to, _to);
}

- (NSArray *) to
{
  NSString *mailto;
 
  mailto = [self queryParameterForKey: @"mailto"];
  if ([mailto length] > 0 && ![to count])
    {
      to = [NSArray arrayWithObject: mailto];
      [to retain];
    }

  return to;
}

- (void) setCc: (NSArray *) _cc
{
  ASSIGN (cc, _cc);
}

- (NSArray *) cc
{
  return cc;
}

- (void) setBcc: (NSArray *) _bcc
{
  ASSIGN (bcc, _bcc);
}

- (NSArray *) bcc
{
  return bcc;
}

- (void) setAddressList: (NSArray *) _addressList
{
  ASSIGN (addressList, _addressList);
}

- (NSArray *) addressList
{
  return addressList;
}

- (void) setAddress: (id) _address
{
  ASSIGN (address, _address);
}

- (id) address
{
  return address;
}

- (void) setItem: (id) _item
{
  ASSIGN (item, _item);
}

- (id) item
{
  return item;
}

- (NSArray *) addressLists
{
  NSMutableArray *ma;
  
  ma = [NSMutableArray arrayWithCapacity:3];
  if ([to isNotNull] && [to count] > 0)
    [ma addObject: to];
  if ([cc isNotNull])
    [ma addObject: cc];
  if ([bcc isNotNull])
    [ma addObject: bcc];

  /* ensure that at least one object is available */
  if ([ma count] == 0)
    {
      NSArray *tmp = [NSArray arrayWithObject:@""];
      ASSIGN (to, tmp);
      [ma addObject:to];
    }

  return ma;
}

- (NSArray *) headers
{
  return headers;
}

- (NSString *) currentHeader
{
  if (addressList == to)
    return @"to";
  else if (addressList == cc)
    return @"cc";

  return @"bcc";
}

/* identifiers */

- (NSString *) nextId
{
  currentIndex++;

  return @"";
}

- (NSString *) currentRowId
{
  [self nextId];
  
  return [NSString stringWithFormat: @"row_%d", currentIndex];
}

- (NSString *) currentPopUpId
{
  
  return [NSString stringWithFormat: @"popup_%d", currentIndex];
}

- (NSString *) currentAddressId
{
  return [NSString stringWithFormat: @"addr_%d", currentIndex];
}

/* handling requests */

- (void) _fillAddresses: (NSMutableArray *) addresses
	     withObject: (id) object
{
  NSEnumerator *list;
  NSString *currentAddress;

  if ([object isKindOfClass: [NSString class]])
    [addresses addObject: object];
  else if ([object isKindOfClass: [NSArray class]])
    {
      list = [object objectEnumerator];
      while ((currentAddress
	      = [[list nextObject] stringByTrimmingSpaces]))
	if ([currentAddress length])
	  [addresses addObject: currentAddress];
    }
}

- (void) getAddressesFromFormValues: (NSDictionary *) _dict
{
  NSMutableArray *rawTo, *rawCc, *rawBcc;
  NSString *idx, *popupKey, *popupValue;
  NSArray *keys;
  unsigned i, count;
  id addr;

  rawTo  = [NSMutableArray arrayWithCapacity:4];
  rawCc  = [NSMutableArray arrayWithCapacity:4];
  rawBcc = [NSMutableArray arrayWithCapacity:2];
  
  keys  = [_dict allKeys];
  count = [keys count];
  for (i = 0; i < count; i++)
    {
      NSString *key;
    
      key = [keys objectAtIndex:i];
      if ([key hasPrefix:@"addr_"])
	{
	  addr = [_dict objectForKey:key];
	  idx  = [self getIndexFromIdentifier:key];
	  popupKey = [NSString stringWithFormat:@"popup_%@", idx];
	  popupValue = [[_dict objectForKey:popupKey] lastObject];
	  if([popupValue isEqualToString:@"0"])
	    [self _fillAddresses: rawTo withObject: addr];
	  else if([popupValue isEqualToString:@"1"])
	    [self _fillAddresses: rawCc withObject: addr];
	  else
	    [self _fillAddresses: rawBcc withObject: addr];
	}
    }
  
  [self setTo: rawTo];
  [self setCc: rawCc];
  [self setBcc: rawBcc];
}

- (NSString *) getIndexFromIdentifier: (NSString *) _identifier
{
  NSRange r;
  
  r = [_identifier rangeOfString: @"_"];

  return [_identifier substringFromIndex: NSMaxRange(r)];
}

- (void) takeValuesFromRequest: (WORequest *) _rq
		     inContext: (WOContext *) _ctx
{
  /* OK, we have a special form value processor */
  NSDictionary *d;

  if ((d = [_rq formValues]) == nil)
    return;

#if 0
  [self debugWithFormat:@"Note: will take values ..."];
  NSLog(@"%s formValues: %@",
        __PRETTY_FUNCTION__,
        d);
#endif
  [self getAddressesFromFormValues: d];
}

- (int) addressCount
{
  return [to count] + [cc count] + [bcc count];
}

@end /* UIxMailToSelection */
