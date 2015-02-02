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
#import "NSData+ActiveSync.h"

#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSObject+Logs.h>

#include <wbxml/wbxml.h>
#include <wbxml/wbxml_conv.h>
#include <wbxml/wbxml_errors.h>

#define WBXMLDEBUG 0

@implementation NSData (ActiveSync)

- (void) _dumpToFile
{
  NSString *path;

  path = [NSString stringWithFormat: @"/tmp/%@.data", [[NSProcessInfo processInfo] globallyUniqueString]];
  [self writeToFile: path  atomically: YES];
  [self errorWithFormat: @"Original data written to: %@", path];
}

//
// Encodes the data in base64 and strip newline characters
// 
- (NSString *) activeSyncRepresentationInContext: (WOContext *) context
{
  return [[self stringByEncodingBase64] stringByReplacingString: @"\n" withString: @""];
}

- (NSData *) wbxml2xml
{
  WBXMLGenXMLParams params;
  NSData *data;

  unsigned int wbxml_len, xml_len, ret;
  unsigned char *wbxml, *xml;

  wbxml = (unsigned char*)[self bytes];
  wbxml_len = [self length];
  xml = NULL;
  xml_len = 0;
  
  params.lang = WBXML_LANG_ACTIVESYNC;
  params.gen_type = WBXML_GEN_XML_INDENT;
  params.indent = 1;
  params.keep_ignorable_ws = FALSE;
    
  ret = wbxml_conv_wbxml2xml_withlen(wbxml, wbxml_len, &xml, &xml_len, &params);
 
  if (ret != WBXML_OK)
    {
      [self errorWithFormat: @"wbxml2xmlFromContent: failed: %s\n", wbxml_errors_string(ret)];
      [self _dumpToFile];
      return nil;
    }

  data = [NSData dataWithBytesNoCopy: xml  length: xml_len  freeWhenDone: YES];

#if WBXMLDEBUG
  [data writeToFile: @"/tmp/protocol.decoded"  atomically: YES];
#endif

  return data;
}


- (NSData *) xml2wbxml
{
  WBXMLConvXML2WBXML *conv;
  NSData *data;

  unsigned int wbxml_len, xml_len, ret;
  unsigned char *wbxml, *xml;

  xml = (unsigned char*)[self bytes];
  xml_len = [self length];
  wbxml = NULL;
  wbxml_len = 0;
  conv = NULL;

  ret = wbxml_conv_xml2wbxml_create(&conv);

  if (ret != WBXML_OK)
    {
      [self logWithFormat: @"xml2wbxmlFromContent: failed: %s\n", wbxml_errors_string(ret)];
      [self _dumpToFile];
      return nil;
    }

  wbxml_conv_xml2wbxml_enable_preserve_whitespaces(conv);
  
  // From libwbxml's changelog in v0.11.0: "The public ID is set to unknown and the DTD is not included. This is required for Microsoft ActiveSync."
  wbxml_conv_xml2wbxml_disable_public_id(conv);
  wbxml_conv_xml2wbxml_disable_string_table(conv);

  ret = wbxml_conv_xml2wbxml_run(conv, xml, xml_len, &wbxml, &wbxml_len);
  
  if (ret != WBXML_OK)
    {
      [self errorWithFormat: @"xml2wbxmlFromContent: failed: %s\n", wbxml_errors_string(ret)];
      [self _dumpToFile];
      free(wbxml);
      wbxml_conv_xml2wbxml_destroy(conv);
      return nil;
    }

  data = [NSData dataWithBytesNoCopy: wbxml  length: wbxml_len  freeWhenDone: YES];

#if WBXMLDEBUG
  [data writeToFile: @"/tmp/protocol.encoded"  atomically: YES];
#endif

  wbxml_conv_xml2wbxml_destroy(conv);

  return data;
}
@end
