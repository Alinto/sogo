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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>

#import <NGMail/NGMailAddress.h>
#import <NGMail/NGMailAddressParser.h>

#import <SOGo/NSString+Utilities.h>

@implementation NGMimeMessage (ActiveSync)

- (void) _addRecipients: (NSEnumerator *) enumerator
                toArray: (NSMutableArray *) recipients
{
  NGMailAddressParser *parser;
  NSEnumerator *addressList;
  NGMailAddress *address;
  NSString *s;

  while ((s = [enumerator nextObject]))
    {
      parser = [NGMailAddressParser mailAddressParserWithString: s];
      addressList = [[parser parseAddressList] objectEnumerator];
      
      while ((address = [addressList nextObject]))
        [recipients addObject: [address address]];
    }
}

- (NSArray *) allRecipients
{
  NSMutableArray *recipients;

  recipients = [NSMutableArray array];

  [self _addRecipients: [[self headersForKey: @"to"] objectEnumerator]
               toArray: recipients];

  [self _addRecipients: [[self headersForKey: @"cc"] objectEnumerator]
               toArray: recipients];

  [self _addRecipients: [[self headersForKey: @"bcc"] objectEnumerator]
               toArray: recipients];

  return recipients;
}
@end
