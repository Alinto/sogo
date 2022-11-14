/*

Copyright (c) 2015, Inverse inc.
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
#import "NGMimeMessage+ActiveSync.h"

#import <Foundation/NSArray.h>

#import <NGMail/NGMailAddress.h>
#import <NGMail/NGMailAddressParser.h>

#import <SOGo/NSString+Utilities.h>

@implementation NGMimeMessage (ActiveSync)

- (NSArray *) allRecipients
{
  NGMailAddressParser *parser;
  NSEnumerator *addressList;
  NSMutableArray *allRecipients;
  NGMailAddress *address;
  NSEnumerator *recipients;
  NSString *s;
  NSString *fieldNames[] = {@"to", @"cc", @"bcc"};
  unsigned int count;

  allRecipients = [NSMutableArray arrayWithCapacity: 16];

  for (count = 0; count < 3; count++)
    {
      recipients = [[self headersForKey: fieldNames[count]] objectEnumerator];
      while ((s = [recipients nextObject]))
        {
          parser = [NGMailAddressParser mailAddressParserWithString: s];
          addressList = [[parser parseAddressList] objectEnumerator];
          while ((address = [addressList nextObject]))
            [allRecipients addObject: [address address]];
       }
    }

  return allRecipients;
}

- (NSArray *) allBareRecipients
{
  NSMutableArray *bareRecipients;
  NSEnumerator *allRecipients;
  NSString *recipient;

  bareRecipients = [NSMutableArray array];

  allRecipients = [[self allRecipients] objectEnumerator];
  while ((recipient = [allRecipients nextObject]))
    [bareRecipients addObject: [recipient pureEMailAddress]];

  return bareRecipients;
}

@end
