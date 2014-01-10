/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the Inverse inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#import "NGVCard+ActiveSync.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGCards/CardElement.h>

@implementation NGVCard (ActiveSync)

- (NSString *) activeSyncRepresentation
{
  NSString *firstName, *lastName;
  NSMutableString *s;
  CardElement *n;

  s = [NSMutableString string];
  n = [self n];
  
  lastName = [n flattenedValueAtIndex: 0 forKey: @""];
  [s appendFormat: @"<LastName xmlns=\"Contacts:\">%@</LastName>", lastName];
  
  
  firstName = [n flattenedValueAtIndex: 1 forKey: @""];
  [s appendFormat: @"<FirstName xmlns=\"Contacts:\">%@</FirstName>", firstName];

  return s;
}

- (void) takeActiveSyncValues: (NSDictionary *) theValues
{
  id o;

   if ((o = [theValues objectForKey: @"CompanyName"]))
     {
       [self setOrg: o  units: nil];
     }
   
   if ((o = [theValues objectForKey: @"Email1Address"]))
     {
       [self addEmail: o  types: [NSArray arrayWithObject: @"pref"]];
     }

   if ((o = [theValues objectForKey: @"Email2Address"]))
     {
       [self addEmail: o types: nil];
     }

   if ((o = [theValues objectForKey: @"Email3Address"]))
     {
       [self addEmail: o  types: nil];
     }

   [self setNWithFamily: [theValues objectForKey: @"LastName"]
                  given: [theValues objectForKey: @"FirstName"]
             additional: nil prefixes: nil suffixes: nil];
   
   if ((o = [theValues objectForKey: @"MobilePhoneNumber"]))
     {
     }
   
   if ((o = [theValues objectForKey: @"Title"]))
     {
       [self setTitle: o];
     }

   if ((o = [theValues objectForKey: @"WebPage"]))
     {
     }
   
}

@end
