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

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGExtensions/NSString+misc.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Envelope.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>
#import <NGMail/NGMimeMessageParser.h>

#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import "SOGoMailFolder.h"
#import "SOGoMailAccount.h"
#import "SOGoMailManager.h"
#import "SOGoMailBodyPart.h"

#import "SOGoMailObject.h"

@implementation SOGoMailObject

static NSArray  *coreInfoKeys = nil;
static NSString *mailETag = nil;
static BOOL heavyDebug         = NO;
static BOOL fetchHeader        = YES;
static BOOL debugOn            = NO;
static BOOL debugBodyStructure = NO;
static BOOL debugSoParts       = NO;

+ (void) initialize
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if ((fetchHeader = ([ud boolForKey: @"SOGoDoNotFetchMailHeader"] ? NO : YES)))
    NSLog(@"Note: fetching full mail header.");
  else
    NSLog(@"Note: not fetching full mail header: 'SOGoDoNotFetchMailHeader'");
  
  /* Note: see SOGoMailManager.m for allowed IMAP4 keys */
  /* Note: "BODY" actually returns the structure! */
  if (fetchHeader) {
    coreInfoKeys = [[NSArray alloc] initWithObjects:
				      @"FLAGS", @"ENVELOPE", @"BODYSTRUCTURE",
				      @"RFC822.SIZE",
				      @"RFC822.HEADER",
				      // not yet supported: @"INTERNALDATE",
				    nil];
  }
  else {
    coreInfoKeys = [[NSArray alloc] initWithObjects:
				      @"FLAGS", @"ENVELOPE", @"BODYSTRUCTURE",
				      @"RFC822.SIZE",
				      // not yet supported: @"INTERNALDATE",
				    nil];
  }

  if (![[ud objectForKey: @"SOGoMailDisableETag"] boolValue]) {
    mailETag = [[NSString alloc] initWithFormat: @"\"imap4url_%d_%d_%03d\"",
				 UIX_MAILER_MAJOR_VERSION,
				 UIX_MAILER_MINOR_VERSION,
				 UIX_MAILER_SUBMINOR_VERSION];
    NSLog(@"Note(SOGoMailObject): using constant etag for mail parts: '%@'", 
	  mailETag);
  }
  else
    NSLog(@"Note(SOGoMailObject): etag caching disabled!");
}

- (void)dealloc {
  [headers    release];
  [headerPart release];
  [coreInfos  release];
  [super dealloc];
}

/* IMAP4 */

- (NSString *) relativeImap4Name
{
  return [nameInContainer stringByDeletingPathExtension];
}

- (NSMutableString *) imap4URLString
{
  NSMutableString *urlString;
  NSString *imap4Name;

  urlString = [container imap4URLString];
  imap4Name = [[self relativeImap4Name] stringByEscapingURL];
  [urlString appendFormat: @"%@", imap4Name];

  return urlString;
}

/* hierarchy */

- (SOGoMailObject *)mailObject {
  return self;
}

/* part hierarchy */

- (NSString *)keyExtensionForPart:(id)_partInfo {
  NSString *mt, *st;
  
  if (_partInfo == nil)
    return nil;
  
  mt = [_partInfo valueForKey: @"type"];
  st = [[_partInfo valueForKey: @"subtype"] lowercaseString];
  if ([mt isEqualToString: @"text"]) {
    if ([st isEqualToString: @"plain"])    return @".txt";
    if ([st isEqualToString: @"html"])     return @".html";
    if ([st isEqualToString: @"calendar"]) return @".ics";
    if ([st isEqualToString: @"x-vcard"])  return @".vcf";
  }
  else if ([mt isEqualToString: @"image"])
    return [@"." stringByAppendingString:st];
  else if ([mt isEqualToString: @"application"]) {
    if ([st isEqualToString: @"pgp-signature"])
      return @".asc";
  }
  
  return nil;
}

- (NSArray *)relationshipKeysWithParts:(BOOL)_withParts {
  /* should return non-multipart children */
  NSMutableArray *ma;
  NSArray *parts;
  unsigned i, count;
  
  parts = [[self bodyStructure] valueForKey: @"parts"];
  if (![parts isNotNull]) 
    return nil;
  if ((count = [parts count]) == 0)
    return nil;
  
  for (i = 0, ma = nil; i < count; i++) {
    NSString *key, *ext;
    id   part;
    BOOL hasParts;
    
    part     = [parts objectAtIndex:i];
    hasParts = [part valueForKey: @"parts"] != nil ? YES:NO;
    if ((hasParts && !_withParts) || (_withParts && !hasParts))
      continue;

    if (ma == nil)
      ma = [NSMutableArray arrayWithCapacity:count - i];
    
    ext = [self keyExtensionForPart:part];
    key = [[NSString alloc] initWithFormat: @"%d%@", i + 1, ext?ext: @""];
    [ma addObject:key];
    [key release];
  }
  return ma;
}

- (NSArray *)toOneRelationshipKeys {
  return [self relationshipKeysWithParts:NO];
}
- (NSArray *)toManyRelationshipKeys {
  return [self relationshipKeysWithParts:YES];
}

/* message */

- (id)fetchParts:(NSArray *)_parts {
  // TODO: explain what it does
  /*
    Called by -fetchPlainTextParts:
  */
  return [[self imap4Connection] fetchURL: [self imap4URL] parts:_parts];
}

/* core infos */

- (BOOL)doesMailExist {
  static NSArray *existsKey = nil;
  id msgs;
  
  if (coreInfos != nil) /* if we have coreinfos, we can use them */
    return [coreInfos isNotNull];
  
  /* otherwise fetch something really simple */
  
  if (existsKey == nil) /* we use size, other suggestions? */
    existsKey = [[NSArray alloc] initWithObjects: @"RFC822.SIZE", nil];
  
  msgs = [self fetchParts:existsKey]; // returns dict
  msgs = [msgs valueForKey: @"fetch"];
  return [msgs count] > 0 ? YES : NO;
}

- (id)fetchCoreInfos {
  id msgs;
  
  if (coreInfos != nil)
    return [coreInfos isNotNull] ? coreInfos : nil;
  
#if 0 // TODO: old code, why was it using clientObject??
  msgs = [[self clientObject] fetchParts:coreInfoKeys]; // returns dict
#else
  msgs = [self fetchParts:coreInfoKeys]; // returns dict
#endif
  if (heavyDebug) [self logWithFormat: @"M: %@", msgs];
  msgs = [msgs valueForKey: @"fetch"];
  if ([msgs count] == 0)
    return nil;
  
  coreInfos = [[msgs objectAtIndex:0] retain];
  return coreInfos;
}

- (id)bodyStructure {
  id body;

  body = [[self fetchCoreInfos] valueForKey: @"body"];
  if (debugBodyStructure)
    [self logWithFormat: @"BODY: %@", body];
  return body;
}

- (NGImap4Envelope *)envelope {
  return [[self fetchCoreInfos] valueForKey: @"envelope"];
}

- (NSString *) subject
{
  return [[self envelope] subject];
}

- (NSCalendarDate *) date
{
  NSTimeZone *userTZ;
  NSCalendarDate *date;

  userTZ = [[context activeUser] timeZone];
  date = [[self envelope] date];
  [date setTimeZone: userTZ];

  return date;
}

- (NSArray *)fromEnvelopeAddresses {
  return [[self envelope] from];
}
- (NSArray *)toEnvelopeAddresses {
  return [[self envelope] to];
}
- (NSArray *)ccEnvelopeAddresses {
  return [[self envelope] cc];
}

- (NSData *)mailHeaderData {
  return [[self fetchCoreInfos] valueForKey: @"header"];
}
- (BOOL)hasMailHeaderInCoreInfos {
  return [[self mailHeaderData] length] > 0 ? YES : NO;
}

- (id)mailHeaderPart {
  NGMimeMessageParser *parser;
  NSData *data;
  
  if (headerPart != nil)
    return [headerPart isNotNull] ? headerPart : nil;
  
  if ([(data = [self mailHeaderData]) length] == 0)
    return nil;
  
  // TODO: do we need to set some delegate method which stops parsing the body?
  parser = [[NGMimeMessageParser alloc] init];
  headerPart = [[parser parsePartFromData:data] retain];
  [parser release]; parser = nil;

  if (headerPart == nil) {
    headerPart = [[NSNull null] retain];
    return nil;
  }
  return headerPart;
}

- (NSDictionary *) mailHeaders
{
  if (!headers)
    headers = [[[self mailHeaderPart] headers] copy];

  return headers;
}

- (id)lookupInfoForBodyPart:(id)_path {
  NSEnumerator *pe;
  NSString *p;
  id info;

  if (![_path isNotNull])
    return nil;
  
  if ((info = [self bodyStructure]) == nil) {
    [self errorWithFormat: @"got no body part structure!"];
    return nil;
  }

  /* ensure array argument */
  
  if ([_path isKindOfClass:[NSString class]]) {
    if ([_path length] == 0)
      return info;
    
    _path = [_path componentsSeparatedByString: @"."];
  }
  
  /* 
     For each path component, eg 1,1,3 
     
     Remember that we need special processing for message/rfc822 which maps the
     namespace of multiparts directly into the main namespace.
     
     TODO(hh): no I don't remember, please explain in more detail!
  */
  pe = [_path objectEnumerator];
  while ((p = [pe nextObject]) != nil && [info isNotNull]) {
    unsigned idx;
    NSArray  *parts;
    NSString *mt;
    
    [self debugWithFormat: @"check PATH: %@", p];
    idx = [p intValue] - 1;

    parts = [info valueForKey: @"parts"];
    mt = [[info valueForKey: @"type"] lowercaseString];
    if ([mt isEqualToString: @"message"]) {
      /* we have special behaviour for message types */
      id body;
      
      if ((body = [info valueForKey: @"body"]) != nil) {
	mt = [body valueForKey: @"type"];
	if ([mt isEqualToString: @"multipart"])
	  parts = [body valueForKey: @"parts"];
	else
	  parts = [NSArray arrayWithObject:body];
      }
    }
    
    if (idx >= [parts count]) {
      [self errorWithFormat:
	      @"body part index out of bounds(idx=%d vs count=%d): %@", 
              (idx + 1), [parts count], info];
      return nil;
    }
    info = [parts objectAtIndex:idx];
  }
  return [info isNotNull] ? info : nil;
}

/* content */

- (NSData *)content {
  NSData *content;
  id     result, fullResult;
  
  fullResult = [self fetchParts:[NSArray arrayWithObject: @"RFC822"]];
  if (fullResult == nil)
    return nil;
  
  if ([fullResult isKindOfClass:[NSException class]])
    return fullResult;
  
  /* extract fetch result */
  
  result = [fullResult valueForKey: @"fetch"];
  if (![result isKindOfClass:[NSArray class]]) {
    [self logWithFormat:
	    @"ERROR: unexpected IMAP4 result (missing 'fetch'): %@", 
	    fullResult];
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason: @"unexpected IMAP4 result"];
  }
  if ([result count] == 0)
    return nil;
  
  result = [result objectAtIndex:0];
  
  /* extract message */
  
  if ((content = [result valueForKey: @"message"]) == nil) {
    [self logWithFormat:
	    @"ERROR: unexpected IMAP4 result (missing 'message'): %@", 
	    result];
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason: @"unexpected IMAP4 result"];
  }
  
  return [[content copy] autorelease];
}

- (NSString *) davContentType
{
  return @"message/rfc822";
}

- (NSString *) contentAsString
{
  NSString *s;
  NSData *content;
  
  if ((content = [self content]) == nil)
    return nil;
  if ([content isKindOfClass:[NSException class]])
    return (id)content;
  
  s = [[NSString alloc] initWithData: content
			encoding: NSISOLatin1StringEncoding];
  if (s == nil) {
    [self logWithFormat:
	    @"ERROR: could not convert data of length %d to string", 
	    [content length]];
    return nil;
  }
  return [s autorelease];
}

/* bulk fetching of plain/text content */

- (BOOL)shouldFetchPartOfType:(NSString *)_type subtype:(NSString *)_subtype {
  /*
    This method decides which parts are 'prefetched' for display. Those are
    usually text parts (the set is currently hardcoded in this method ...).
  */
  _type    = [_type    lowercaseString];
  _subtype = [_subtype lowercaseString];
  
  return (([_type isEqualToString: @"text"]
           && ([_subtype isEqualToString: @"plain"]
               || [_subtype isEqualToString: @"html"]
               || [_subtype isEqualToString: @"calendar"]))
          || ([_type isEqualToString: @"application"]
              && ([_subtype isEqualToString: @"pgp-signature"]
                  || [_subtype hasPrefix: @"x-vnd.kolab."])));
}

- (void)addRequiredKeysOfStructure:(id)_info path:(NSString *)_p
  toArray:(NSMutableArray *)_keys
  recurse:(BOOL)_recurse
{
  /* 
     This is used to collect the set of IMAP4 fetch-keys required to fetch
     the basic parts of the body structure. That is, to fetch all parts which
     are displayed 'inline' in a single IMAP4 fetch.
     
     The method calls itself recursively to walk the body structure.
  */
  NSArray  *parts;
  unsigned i, count;
  BOOL fetchPart;
  id body;
  
  /* Note: if the part itself doesn't qualify, we still check subparts */
  fetchPart = [self shouldFetchPartOfType:[_info valueForKey: @"type"]
		    subtype:[_info valueForKey: @"subtype"]];
  if (fetchPart) {
    NSString *k;
    
    if ([_p length] > 0) {
      k = [[@"body[" stringByAppendingString:_p] stringByAppendingString: @"]"];
    }
    else {
      /*
	for some reason we need to add ".TEXT" for plain text stuff on root
	entities?
	TODO: check with HTML
      */
      k = @"body[text]";
    }
    [_keys addObject:k];
  }
  
  if (!_recurse)
    return;
  
  /* recurse */
  
  parts = [(NSDictionary *)_info objectForKey: @"parts"];
  for (i = 0, count = [parts count]; i < count; i++) {
    NSString *sp;
    id childInfo;
    
    sp = ([_p length] > 0)
      ? [_p stringByAppendingFormat: @".%d", i + 1]
      : [NSString stringWithFormat: @"%d", i + 1];
    
    childInfo = [parts objectAtIndex:i];
    
    [self addRequiredKeysOfStructure:childInfo path:sp toArray:_keys
	  recurse:YES];
  }
  
  /* check body */
  
  if ((body = [(NSDictionary *)_info objectForKey: @"body"]) != nil) {
    NSString *sp;

    sp = [[body valueForKey: @"type"] lowercaseString];
    if ([sp isEqualToString: @"multipart"])
      sp = _p;
    else
      sp = [_p length] > 0 ? [_p stringByAppendingString: @".1"] : @"1";
    [self addRequiredKeysOfStructure:body path:sp toArray:_keys
	  recurse:YES];
  }
}

- (NSArray *)plainTextContentFetchKeys {
  /*
    The name is not 100% correct. The method returns all body structure fetch
    keys which are marked by the -shouldFetchPartOfType:subtype: method.
  */
  NSMutableArray *ma;
  
  ma = [NSMutableArray arrayWithCapacity:4];
  [self addRequiredKeysOfStructure:[[self clientObject] bodyStructure]
	path: @"" toArray:ma recurse:YES];
  return ma;
}

- (NSDictionary *)fetchPlainTextParts:(NSArray *)_fetchKeys {
  // TODO: is the name correct or does it also fetch other parts?
  NSMutableDictionary *flatContents;
  unsigned i, count;
  id result;
  
  [self debugWithFormat: @"fetch keys: %@", _fetchKeys];
  
  result = [self fetchParts:_fetchKeys];
  result = [result valueForKey: @"RawResponse"]; // hackish
  
  // Note: -valueForKey: doesn't work!
  result = [(NSDictionary *)result objectForKey: @"fetch"]; 
  
  count        = [_fetchKeys count];
  flatContents = [NSMutableDictionary dictionaryWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSString *key;
    NSData   *data;
    
    key  = [_fetchKeys objectAtIndex:i];
    data = [(NSDictionary *)[(NSDictionary *)result objectForKey:key] 
			    objectForKey: @"data"];
    
    if (![data isNotNull]) {
      [self errorWithFormat: @"got no data for key: %@", key];
      continue;
    }
    
    if ([key isEqualToString: @"body[text]"])
      key = @""; // see key collector for explanation (TODO: where?)
    else if ([key hasPrefix: @"body["]) {
      NSRange r;
      
      key = [key substringFromIndex:5];
      r   = [key rangeOfString: @"]"];
      if (r.length > 0)
	key = [key substringToIndex:r.location];
    }
    [flatContents setObject:data forKey:key];
  }
  return flatContents;
}

- (NSDictionary *)fetchPlainTextParts {
  return [self fetchPlainTextParts:[self plainTextContentFetchKeys]];
}

/* convert parts to strings */

- (NSString *)stringForData:(NSData *)_data partInfo:(NSDictionary *)_info
{
  NSString *charset, *encoding, *s;
  NSData *mailData;
  
  if (![_data isNotNull])
    return nil;

  s = nil;

  encoding = [[_info objectForKey: @"encoding"] lowercaseString];

  if ([encoding isEqualToString: @"7bit"]
      || [encoding isEqualToString: @"8bit"])
    mailData = _data;
  else if ([encoding isEqualToString: @"base64"])
    mailData = [_data dataByDecodingBase64];
  else if ([encoding isEqualToString: @"quoted-printable"])
    mailData = [_data dataByDecodingQuotedPrintable];
  
  charset = [[_info valueForKey: @"parameterList"] valueForKey: @"charset"];
  if (![charset length])
    {
      s = [[NSString alloc] initWithData:mailData encoding:NSUTF8StringEncoding];
      [s autorelease];
    }
  else
    s = [NSString stringWithData: mailData
                  usingEncodingNamed: charset];

  return s;
}

- (NSDictionary *)stringifyTextParts:(NSDictionary *)_datas {
  NSMutableDictionary *md;
  NSEnumerator *keys;
  NSString     *key;
  
  md   = [NSMutableDictionary dictionaryWithCapacity:4];
  keys = [_datas keyEnumerator];
  while ((key = [keys nextObject]) != nil) {
    NSDictionary *info;
    NSString *s;
    
    info = [self lookupInfoForBodyPart:key];
    if ((s = [self stringForData:[_datas objectForKey:key] partInfo:info]))
      [md setObject:s forKey:key];
  }
  return md;
}
- (NSDictionary *)fetchPlainTextStrings:(NSArray *)_fetchKeys {
  /*
    The fetched parts are NSData objects, this method converts them into
    NSString objects based on the information inside the bodystructure.
    
    The fetch-keys are body fetch-keys like: body[text] or body[1.2.3].
    The keys in the result dictionary are "" for 'text' and 1.2.3 for parts.
  */
  NSDictionary *datas;
  
  if ((datas = [self fetchPlainTextParts:_fetchKeys]) == nil)
    return nil;
  if ([datas isKindOfClass:[NSException class]])
    return datas;
  
  return [self stringifyTextParts:datas];
}

/* flags */

- (NSException *) addFlags: (id) _flags
{
  return [[self imap4Connection] addFlags:_flags toURL: [self imap4URL]];
}

- (NSException *) removeFlags: (id) _flags
{
  return [[self imap4Connection] removeFlags:_flags toURL: [self imap4URL]];
}

/* permissions */

- (BOOL) isDeletionAllowed
{
  NSArray *parentAcl;
  NSString *login;

  login = [[context activeUser] login];
  parentAcl = [[self container] aclsForUser: login];

  return [parentAcl containsObject: SOGoRole_ObjectEraser];
}

/* name lookup */

- (id) lookupImap4BodyPartKey: (NSString *) _key
		    inContext: (id) _ctx
{
  // TODO: we might want to check for existence prior controller creation
  Class clazz;
  
  clazz = [SOGoMailBodyPart bodyPartClassForKey:_key inContext:_ctx];

  return [clazz objectWithName:_key inContainer: self];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  id obj;
  
  /* first check attributes directly bound to the application */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]) != nil)
    return obj;
  
  /* lookup body part */
  
  if ([self isBodyPartKey:_key inContext:_ctx]) {
    if ((obj = [self lookupImap4BodyPartKey:_key inContext:_ctx]) != nil) {
      if (debugSoParts) 
	[self logWithFormat: @"mail looked up part %@: %@", _key, obj];
      return obj;
    }
  }
  
  /* return 404 to stop acquisition */
  return [NSException exceptionWithHTTPStatus:404 /* Not Found */
		      reason: @"Did not find mail method or part-reference!"];
}

/* WebDAV */

- (BOOL)davIsCollection {
  /* while a mail has child objects, it should appear as a file in WebDAV */
  return NO;
}

- (id)davContentLength {
  return [[self fetchCoreInfos] valueForKey: @"size"];
}

- (NSDate *)davCreationDate {
  // TODO: use INTERNALDATE once NGImap4 supports that
  return nil;
}
- (NSDate *)davLastModified {
  return [self davCreationDate];
}

- (NSException *)davMoveToTargetObject:(id)_target newName:(NSString *)_name
  inContext:(id)_ctx
{
  [self logWithFormat: @"TODO: should move mail as '%@' to: %@",
	_name, _target];
  return [NSException exceptionWithHTTPStatus:501 /* Not Implemented */
		      reason: @"not implemented"];
}

- (NSException *)davCopyToTargetObject:(id)_target newName:(NSString *)_name
  inContext:(id)_ctx
{
  /* 
     Note: this is special because we create SOGoMailObject's even if they do
           not exist (for performance reasons).

     Also: we cannot really take a target resource, the ID will be assigned by
           the IMAP4 server.
	   We even cannot return a 'location' header instead because IMAP4
	   doesn't tell us the new ID.
  */
  NSURL *destImap4URL;
  
  destImap4URL = ([_name length] == 0)
    ? [[_target container] imap4URL]
    : [_target imap4URL];
  
  return [[self mailManager] copyMailURL:[self imap4URL] 
			     toFolderURL:destImap4URL
			     password:[self imap4Password]];
}

/* actions */

- (id)GETAction:(id)_ctx {
  NSException *error;
  WOResponse  *r;
  NSData      *content;
  
  if ((error = [self matchesRequestConditionInContext:_ctx]) != nil) {
    /* check whether the mail still exists */
    if (![self doesMailExist]) {
      return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			  reason: @"mail was deleted"];
    }
    return error; /* return 304 or 416 */
  }
  
  content = [self content];
  if ([content isKindOfClass:[NSException class]])
    return content;
  if (content == nil) {
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason: @"did not find IMAP4 message"];
  }
  
  r = [(WOContext *)_ctx response];
  [r setHeader: @"message/rfc822" forKey: @"content-type"];
  [r setContent:content];
  return r;
}

/* operations */

- (NSException *)trashInContext:(id)_ctx {
  /*
    Trashing is three actions:
    a) copy to trash folder
    b) mark mail as deleted
    c) expunge folder
    
    In case b) or c) fails, we can't do anything because IMAP4 doesn't tell us
    the ID used in the trash folder.
  */
  SOGoMailFolder *trashFolder;
  NSException    *error;

  // TODO: check for safe HTTP method
  
  trashFolder = [[self mailAccountFolder] trashFolderInContext:_ctx];
  if ([trashFolder isKindOfClass:[NSException class]])
    return (NSException *)trashFolder;
  if (![trashFolder isNotNull]) {
    return [NSException exceptionWithHTTPStatus:500 /* Server Error */
			reason: @"Did not find Trash folder!"];
  }
  [trashFolder flushMailCaches];

  /* a) copy */
  
  error = [self davCopyToTargetObject:trashFolder
		newName: @"fakeNewUnusedByIMAP4" /* autoassigned */
		inContext:_ctx];
  if (error != nil) return error;
  
  /* b) mark deleted */
  
  error = [[self imap4Connection] markURLDeleted:[self imap4URL]];
  if (error != nil) return error;
  
  /* c) expunge */

  error = [[self imap4Connection] expungeAtURL:[[self container] imap4URL]];
  if (error != nil) return error; // TODO: unflag as deleted?
  [self flushMailCaches];
  
  return nil;
}

- (NSException *) moveToFolderNamed: (NSString *) folderName
                          inContext: (id)_ctx
{
  /*
    Trashing is three actions:
    a) copy to trash folder
    b) mark mail as deleted
    c) expunge folder
    
    In case b) or c) fails, we can't do anything because IMAP4 doesn't tell us
    the ID used in the trash folder.
  */
  SOGoMailAccounts *destFolder;
  NSEnumerator *folders;
  NSString *currentFolderName, *reason;
  NSException    *error;

  // TODO: check for safe HTTP method

  destFolder = [self mailAccountsFolder];
  folders = [[folderName componentsSeparatedByString: @"/"] objectEnumerator];
  currentFolderName = [folders nextObject];
  currentFolderName = [folders nextObject];

  while (currentFolderName)
    {
      destFolder = [destFolder lookupName: currentFolderName
                               inContext: _ctx
                               acquire: NO];
      if ([destFolder isKindOfClass: [NSException class]])
        return (NSException *) destFolder;
      currentFolderName = [folders nextObject];
    }

  if (!([destFolder isKindOfClass: [SOGoMailFolder class]]
        && [destFolder isNotNull]))
    {
      reason = [NSString stringWithFormat: @"Did not find folder name '%@'!",
                         folderName];
      return [NSException exceptionWithHTTPStatus:500 /* Server Error */
                          reason: reason];
    }
  [destFolder flushMailCaches];

  /* a) copy */
  
  error = [self davCopyToTargetObject: destFolder
		newName: @"fakeNewUnusedByIMAP4" /* autoassigned */
		inContext:_ctx];
  if (error != nil) return error;

  /* b) mark deleted */
  
  error = [[self imap4Connection] markURLDeleted: [self imap4URL]];
  if (error != nil) return error;
  
  /* c) expunge */

  error = [[self imap4Connection] expungeAtURL:[[self container] imap4URL]];
  if (error != nil) return error; // TODO: unflag as deleted?
  [self flushMailCaches];
  
  return nil;
}

- (NSException *)delete {
  /* 
     Note: delete is different to DELETEAction: for mails! The 'delete' runs
           either flags a message as deleted or moves it to the Trash while
	   the DELETEAction: really deletes a message (by flagging it as
	   deleted _AND_ performing an expunge).
  */
  // TODO: copy to Trash folder
  NSException *error;

  // TODO: check for safe HTTP method
  
  error = [[self imap4Connection] markURLDeleted:[self imap4URL]];
  return error;
}
- (id)DELETEAction:(id)_ctx {
  NSException *error;
  
  // TODO: ensure safe HTTP method
  
  error = [[self imap4Connection] markURLDeleted:[self imap4URL]];
  if (error != nil) return error;
  
  error = [[self imap4Connection] expungeAtURL:[[self container] imap4URL]];
  if (error != nil) return error; // TODO: unflag as deleted?
  
  return [NSNumber numberWithBool:YES]; /* delete was successful */
}

/* some mail classification */

- (BOOL)isKolabObject {
  NSDictionary *h;
  
  if ((h = [self mailHeaders]) != nil)
    return [[h objectForKey: @"x-kolab-type"] isNotEmpty];
  
  // TODO: we could check the body structure?
  
  return NO;
}

- (BOOL)isMailingListMail {
  NSDictionary *h;
  
  if ((h = [self mailHeaders]) == nil)
    return NO;
  
  return [[h objectForKey: @"list-id"] isNotEmpty];
}

- (BOOL)isVirusScanned {
  NSDictionary *h;
  
  if ((h = [self mailHeaders]) == nil)
    return NO;
  
  if (![[h objectForKey: @"x-virus-status"]  isNotEmpty]) return NO;
  if (![[h objectForKey: @"x-virus-scanned"] isNotEmpty]) return NO;
  return YES;
}

- (NSString *)scanListHeaderValue:(id)_value
  forFieldWithPrefix:(NSString *)_prefix
{
  /* Note: not very tolerant on embedded commands and <> */
  // TODO: does not really belong here, should be a header-field-parser
  NSRange r;
  
  if (![_value isNotEmpty])
    return nil;
  
  if ([_value isKindOfClass:[NSArray class]]) {
    NSEnumerator *e;
    id value;

    e = [_value objectEnumerator];
    while ((value = [e nextObject]) != nil) {
      value = [self scanListHeaderValue:value forFieldWithPrefix:_prefix];
      if (value != nil) return value;
    }
    return nil;
  }
  
  if (![_value isKindOfClass:[NSString class]])
    return nil;
  
  /* check for commas in string values */
  r = [_value rangeOfString: @","];
  if (r.length > 0) {
    return [self scanListHeaderValue:[_value componentsSeparatedByString: @","]
		 forFieldWithPrefix:_prefix];
  }

  /* value qualifies */
  if (![(NSString *)_value hasPrefix:_prefix])
    return nil;
  
  /* unquote */
  if ([_value characterAtIndex:0] == '<') {
    r = [_value rangeOfString: @">"];
    _value = (r.length == 0)
      ? [_value substringFromIndex:1]
      : [_value substringWithRange:NSMakeRange(1, r.location - 2)];
  }

  return _value;
}

- (NSString *)mailingListArchiveURL {
  return [self scanListHeaderValue:
		 [[self mailHeaders] objectForKey: @"list-archive"]
	       forFieldWithPrefix: @"<http://"];
}
- (NSString *)mailingListSubscribeURL {
  return [self scanListHeaderValue:
		 [[self mailHeaders] objectForKey: @"list-subscribe"]
	       forFieldWithPrefix: @"<http://"];
}
- (NSString *)mailingListUnsubscribeURL {
  return [self scanListHeaderValue:
		 [[self mailHeaders] objectForKey: @"list-unsubscribe"]
	       forFieldWithPrefix: @"<http://"];
}

/* etag support */

- (id)davEntityTag {
  /*
    Note: There is one thing which *can* change for an existing message,
          those are the IMAP4 flags (and annotations, which we do not use).
	  Since we don't render the flags, it should be OK, if this changes
	  we must embed the flagging into the etag.
  */
  return mailETag;
}
- (int)zlGenerationCount {
  return 0; /* mails never change */
}

/* Outlook mail tagging */

- (NSString *)outlookMessageClass {
  NSString *type;
  
  if ((type = [[self mailHeaders] objectForKey: @"x-kolab-type"]) != nil) {
    if ([type isEqualToString: @"application/x-vnd.kolab.contact"])
      return @"IPM.Contact";
    if ([type isEqualToString: @"application/x-vnd.kolab.task"])
      return @"IPM.Task";
    if ([type isEqualToString: @"application/x-vnd.kolab.event"])
      return @"IPM.Appointment";
    if ([type isEqualToString: @"application/x-vnd.kolab.note"])
      return @"IPM.Note";
    if ([type isEqualToString: @"application/x-vnd.kolab.journal"])
      return @"IPM.Journal";
  }
  
  return @"IPM.Message"; /* email, default class */
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return [container aclsForUser: uid];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SOGoMailObject */
