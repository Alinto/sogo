/*
  Copyright (C) 2005 Helge Hess

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

// Note: this does not yet produce valid XML output

#import <Foundation/NSObject.h>
#include <SaxObjC/SaxObjC.h>

@interface vcf2xml : NSObject
{
  id<NSObject,SaxXMLReader> parser;
  id sax;
}

- (int)runWithArguments:(NSArray *)_args;

@end

#include "common.h"

@interface MySAXHandler : SaxDefaultHandler
{
  id  locator;
  int indent;

  NSString *lastNS;
}

- (void)indent;

@end

@implementation vcf2xml

- (id)init {
  if ((self = [super init]) != nil) {
    self->parser = [[[SaxXMLReaderFactory standardXMLReaderFactory] 
		      createXMLReaderForMimeType:@"text/x-vcard"] retain];
    if (parser == nil) {
      fprintf(stderr, "Error: could not load a vCard SAX driver bundle!\n");
      exit(2);
    }
    //NSLog(@"Using parser: %@", self->parser);
    
    self->sax = [[MySAXHandler alloc] init];
    [parser setContentHandler:self->sax];
    [parser setErrorHandler:self->sax];
  }
  return self;
}

- (void)dealloc {
  [self->sax    release];
  [self->parser release];
  [super dealloc];
}

/* process files */

- (void)processFile:(NSString *)_path {
  [self->parser parseFromSystemId:_path];
}

/* error handling */

- (NSException *)handleException:(NSException *)_exc onPath:(NSString *)_p {
  fprintf(stderr, "Error: catched exception on path '%s': %s\n",
	  [_p cString], [[_exc description] cString]);
  return nil;
}

/* main entry */

- (int)runWithArguments:(NSArray *)_args {
  NSEnumerator *args;
  NSString     *arg;
  
  /* begin processing */
  
  args = [_args objectEnumerator];
  [args nextObject]; // skip tool name ...
  
  while ((arg = [args nextObject]) != nil) {
    NSAutoreleasePool *pool2;
    
    if ([arg hasPrefix:@"-"]) { /* consume defaults */
      [args nextObject];
      continue;
    }
    
    pool2 = [[NSAutoreleasePool alloc] init];


    if (![arg isAbsolutePath]) {
      arg = [[[NSFileManager defaultManager] currentDirectoryPath]
	      stringByAppendingPathComponent:arg];
    }
    
    NS_DURING
      [self->parser parseFromSystemId:arg];
    NS_HANDLER
      [[self handleException:localException onPath:arg] raise];
    NS_ENDHANDLER;
    
    [pool2 release];
  }
  return 0;
}

@end /* vcf2xml */


@implementation MySAXHandler

- (void)dealloc {
  [self->lastNS  release];
  [self->locator release];
  [super dealloc];
}

/* output */

- (void)indent {
  int i;
  
  for (i = 0; i < (self->indent * 4); i++)
    fputc(' ', stdout);
}

/* documents */

- (void)setDocumentLocator:(id<NSObject,SaxLocator>)_loc {
  [self->locator autorelease];
  self->locator = [_loc retain];
}

- (void)startDocument {
  //puts("start document ..");
  //self->indent++;
}
- (void)endDocument {
  //self->indent--;
  //puts("end document.");
}

- (void)startPrefixMapping:(NSString *)_prefix uri:(NSString *)_uri {
  [self indent];
  //printf("ns-map: %s=%s\n", [_prefix cString], [_uri cString]);
}
- (void)endPrefixMapping:(NSString *)_prefix {
  [self indent];
  //printf("ns-unmap: %s\n", [_prefix cString]);
}

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attrs
{
  int i, c;
  [self indent];
  printf("<%s", [_localName cString]);
  
  if ([_ns length] > 0) {
    if ([_ns isEqualToString:self->lastNS])
      ;
    else {
      printf(" xmlns='%s'", [_ns cString]);
      ASSIGNCOPY(self->lastNS, _ns);
    }
  }
  
  for (i = 0, c = [_attrs count]; i < c; i++) {
    NSString *type;
    NSString *ans;

    ans = [_attrs uriAtIndex:i];
    
    printf(" %s=\"%s\"",
           [[_attrs nameAtIndex:i] cString],
           [[_attrs valueAtIndex:i] cString]);
    
    if (![_ns isEqualToString:ans])
      printf("(ns=%s)", [ans cString]);
    
    type = [_attrs typeAtIndex:i];
    if (![type isEqualToString:@"CDATA"] && (type != nil))
      printf("[%s]", [type cString]);
  }
  puts(">");
  self->indent++;
}
- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  self->indent--;
  [self indent];
  printf("</%s>\n", [_localName cString]);
}

- (void)characters:(unichar *)_chars length:(NSUInteger)_len {
  NSString *str;
  id tmp;
  NSUInteger i, len;

  if (_len == 0) {
    [self indent];
    printf("\"\"\n");
    return;
  }
  
  for (i = 0; i < _len; i++) {
    if (_chars[i] > 255) {
      NSLog(@"detected large char: o%04o d%03i h%04X",
            _chars[i], _chars[i], _chars[i]);
    }
  }
  
  str = [NSString stringWithCharacters:_chars length:_len];
  len = [str length];
  
  tmp = [str componentsSeparatedByString:@"\n"];
  str = [tmp componentsJoinedByString:@"\\n"];
  tmp = [str componentsSeparatedByString:@"\r"];
  str = [tmp componentsJoinedByString:@"\\r"];
  
  [self indent];
  printf("\"%s\"\n", [str cString]);
}
- (void)ignorableWhitespace:(unichar *)_chars length:(NSUInteger)_len {
  NSString *data;
  id tmp;

  data = [NSString stringWithCharacters:_chars length:_len];
  tmp  = [data componentsSeparatedByString:@"\n"];
  data = [tmp componentsJoinedByString:@"\\n"];
  tmp  = [data componentsSeparatedByString:@"\r"];
  data = [tmp componentsJoinedByString:@"\\r"];
  
  [self indent];
  printf("whitespace: \"%s\"\n", [data cString]);
}

- (void)processingInstruction:(NSString *)_pi data:(NSString *)_data {
  [self indent];
  printf("PI: '%s' '%s'\n", [_pi cString], [_data cString]);
}

#if 0
- (xmlEntityPtr)getEntity:(NSString *)_name {
  NSLog(@"get entity %@", _name);
  return NULL;
}
- (xmlEntityPtr)getParameterEntity:(NSString *)_name {
  NSLog(@"get para entity %@", _name);
  return NULL;
}
#endif

/* entities */

- (id)resolveEntityWithPublicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
{
  [self indent];
  printf("shall resolve entity with '%s' '%s'",
         [_pubId cString], [_sysId cString]);
  return nil;
}

/* errors */

- (void)warning:(SaxParseException *)_exception {
  NSLog(@"warning(%@:%i): %@",
        [[_exception userInfo] objectForKey:@"publicId"],
        [[[_exception userInfo] objectForKey:@"line"] intValue],
        [_exception reason]);
}

- (void)error:(SaxParseException *)_exception {
  NSLog(@"error(%@:%i): %@",
        [[_exception userInfo] objectForKey:@"publicId"],
        [[[_exception userInfo] objectForKey:@"line"] intValue],
        [_exception reason]);
}

- (void)fatalError:(SaxParseException *)_exception {
  NSLog(@"fatal error(%@:%i): %@",
        [[_exception userInfo] objectForKey:@"publicId"],
        [[[_exception userInfo] objectForKey:@"line"] intValue],
        [_exception reason]);
  [_exception raise];
}

@end /* MySAXHandler */



int main(int argc, char **argv, char **env)  {
  NSAutoreleasePool *pool;
  vcf2xml *tool;
  int rc;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  if ((tool = [[vcf2xml alloc] init])) {
    NS_DURING
      rc = [tool runWithArguments:[[NSProcessInfo processInfo] arguments]];
    NS_HANDLER
      abort();
    NS_ENDHANDLER;
    
    [tool release];
  }
  else
    rc = 1;
  
  [pool release];
  return rc;
}
