/*
  Copyright (C) 2007-2009 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
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
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGExtensions/NSString+misc.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Envelope.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>
#import <NGMail/NGMimeMessageParser.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/NSCalendarDate+SOGo.h>

#import "NSString+Mail.h"
#import "NSData+Mail.h"
#import "SOGoMailFolder.h"
#import "SOGoMailAccount.h"
#import "SOGoMailAccounts.h"
#import "SOGoMailManager.h"
#import "SOGoMailBodyPart.h"

#import "SOGoMailObject.h"

@implementation SOGoMailObject

NSArray *SOGoMailCoreInfoKeys = nil;
static NSString *mailETag = nil;
static BOOL heavyDebug         = NO;
static BOOL debugOn            = NO;
static BOOL debugBodyStructure = NO;
static BOOL debugSoParts       = NO;

+ (void) initialize
{
  if (!SOGoMailCoreInfoKeys)
    {
      /* Note: see SOGoMailManager.m for allowed IMAP4 keys */
      SOGoMailCoreInfoKeys
        = [[NSArray alloc] initWithObjects:
                             @"FLAGS", @"ENVELOPE", @"BODYSTRUCTURE",
                           @"RFC822.SIZE",
                           @"RFC822.HEADER",
                           // not yet supported: @"INTERNALDATE",
                           nil];

      /* The following disabled code should not be needed, except if we use
         annotations (see davEntityTag below) */
      // if (![[ud objectForKey: @"SOGoMailDisableETag"] boolValue]) {
      mailETag = [[NSString alloc] initWithFormat: @"\"imap4url_%d_%d_%03d\"",
                                   UIX_MAILER_MAJOR_VERSION,
                                   UIX_MAILER_MINOR_VERSION,
                                   UIX_MAILER_SUBMINOR_VERSION];
    }
}

- (void) dealloc
{
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

/* hierarchy */

- (SOGoMailObject *)mailObject {
  return self;
}

/* part hierarchy */

- (NSString *) keyExtensionForPart: (id) _partInfo
{
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
    key = [[NSString alloc] initWithFormat: @"%d%@", i + 1, ((id)ext?(id)ext: (id)@"")];
    [ma addObject:key];
    [key release];
  }
  return ma;
}

- (NSArray *) toOneRelationshipKeys
{
  return [self relationshipKeysWithParts:NO];
}

- (NSArray *) toManyRelationshipKeys
{
  return [self relationshipKeysWithParts:YES];
}

/* message */

- (id) fetchParts: (NSArray *) _parts
{
  // TODO: explain what it does
  /*
    Called by -fetchPlainTextParts:
  */
  return [[self imap4Connection] fetchURL: [self imap4URL] parts:_parts];
}

/* core infos */

- (BOOL) doesMailExist
{
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

- (id) fetchCoreInfos
{
  id msgs;
  int i;

  if (!coreInfos)
    {
      msgs = [self fetchParts: SOGoMailCoreInfoKeys]; // returns dict
      if (heavyDebug)
	[self logWithFormat: @"M: %@", msgs];
      msgs = [msgs valueForKey: @"fetch"];
      
      // We MUST honor untagged IMAP responses here otherwise we could
      // return really borken and nasty results.
      if ([msgs count] > 0)
	{
	  for (i = 0; i < [msgs count]; i++)
	    {
	      coreInfos = [msgs objectAtIndex: i];
	      
	      if ([[coreInfos objectForKey: @"uid"] intValue] == [[self nameInContainer] intValue])
		break;

	      coreInfos = nil;
	    }
	}
      [coreInfos retain];
    }

  return coreInfos;
}

- (void) setCoreInfos: (NSDictionary *) newCoreInfos
{
  ASSIGN (coreInfos, newCoreInfos);
}

- (id) bodyStructure
{
  id bodyStructure;

  bodyStructure = [[self fetchCoreInfos] valueForKey: @"bodystructure"];
  if (debugBodyStructure)
    [self logWithFormat: @"BODYSTRUCTURE: %@", bodyStructure];

  return bodyStructure;
}

- (NGImap4Envelope *) envelope
{
  return [[self fetchCoreInfos] valueForKey: @"envelope"];
}

- (NSString *) subject
{
  return [[self envelope] subject];
}

- (NSString *) displayName
{
  return [self decodedSubject];
}

- (NSString *) decodedSubject
{
  return [[self subject] decodedHeader];
}

- (NSCalendarDate *) date
{
  SOGoUserDefaults *ud;
  NSCalendarDate *date;

  ud = [[context activeUser] userDefaults];
  date = [[self envelope] date];
  [date setTimeZone: [ud timeZone]];

  return date;
}

- (NSArray *) fromEnvelopeAddresses
{
  return [[self envelope] from];
}

- (NSArray *) toEnvelopeAddresses
{
  return [[self envelope] to];
}

- (NSArray *) ccEnvelopeAddresses
{
  return [[self envelope] cc];
}

- (NSArray *) bccEnvelopeAddresses
{
  return [[self envelope] bcc];
}

- (NSArray *) replyToEnvelopeAddresses
{
  return [[self envelope] replyTo];
}

- (NSData *) mailHeaderData
{
  return [[self fetchCoreInfos] valueForKey: @"header"];
}

- (BOOL) hasMailHeaderInCoreInfos
{
  return [[self mailHeaderData] length] > 0 ? YES : NO;
}

- (id) mailHeaderPart
{
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

- (id) lookupInfoForBodyPart: (id) _path
{
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
    if ([_path length] == 0 || [_path isEqualToString: @"text"])
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

- (NSData *) content
{
  NSData *content;
  id     result, fullResult;
  
  fullResult = [self fetchParts: [NSArray arrayWithObject: @"RFC822"]];
  if (fullResult == nil)
    return nil;
  
  if ([fullResult isKindOfClass: [NSException class]])
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
  id s;
  NSData *content;

  content = [self content];
  if (content)
    {
      if ([content isKindOfClass: [NSData class]])
	{
#warning we ignore the charset here?
	  s = [[NSString alloc] initWithData: content
				encoding: NSISOLatin1StringEncoding];
	  if (s)
	    [s autorelease];
	  else
	    [self logWithFormat:
		    @"ERROR: could not convert data of length %d to string", 
		  [content length]];
	}
      else
	s = content;
    }
  else
    s = nil;

  return s;
}

/* bulk fetching of plain/text content */

// - (BOOL) shouldFetchPartOfType: (NSString *) _type
// 		       subtype: (NSString *) _subtype
// {
//   /*
//     This method decides which parts are 'prefetched' for display. Those are
//     usually text parts (the set is currently hardcoded in this method ...).
//   */
//   _type    = [_type    lowercaseString];
//   _subtype = [_subtype lowercaseString];
  
//   return (([_type isEqualToString: @"text"]
//            && ([_subtype isEqualToString: @"plain"]
//                || [_subtype isEqualToString: @"html"]
//                || [_subtype isEqualToString: @"calendar"]))
//           || ([_type isEqualToString: @"application"]
//               && ([_subtype isEqualToString: @"pgp-signature"]
//                   || [_subtype hasPrefix: @"x-vnd.kolab."])));
// }

- (void) addRequiredKeysOfStructure: (NSDictionary *) info
			       path: (NSString *) p
			    toArray: (NSMutableArray *) keys
		      acceptedTypes: (NSArray *) types
                           withPeek: (BOOL) withPeek
{
  /* 
     This is used to collect the set of IMAP4 fetch-keys required to fetch
     the basic parts of the body structure. That is, to fetch all parts which
     are displayed 'inline' in a single IMAP4 fetch.
     
     The method calls itself recursively to walk the body structure.
  */
  NSArray *parts;
  unsigned i, count;
  NSString *k;
  id body;
  NSString *bodyToken, *sp, *mimeType;
  id childInfo;

  bodyToken = (withPeek ? @"body.peek" : @"body");

  mimeType = [[NSString stringWithFormat: @"%@/%@",
			[info valueForKey: @"type"],
			[info valueForKey: @"subtype"]]
	       lowercaseString];
  if ([types containsObject: mimeType])
    {
      if ([p length] > 0)
	k = [NSString stringWithFormat: @"%@[%@]", bodyToken, p];
      else
	{
	  /*
	    for some reason we need to add ".TEXT" for plain text stuff on root
	    entities?
	    TODO: check with HTML
	  */
	  k = [NSString stringWithFormat: @"%@[text]", bodyToken];
	}
      [keys addObject: [NSDictionary dictionaryWithObjectsAndKeys: k, @"key",
				     mimeType, @"mimeType", nil]];
    }

  parts = [info objectForKey: @"parts"];
  count = [parts count];
  for (i = 0; i < count; i++)
    {
      sp = (([p length] > 0)
	    ? (id)[p stringByAppendingFormat: @".%d", i + 1]
	    : (id)[NSString stringWithFormat: @"%d", i + 1]);
      
      childInfo = [parts objectAtIndex: i];
      
      [self addRequiredKeysOfStructure: childInfo
	    path: sp toArray: keys
	    acceptedTypes: types
            withPeek: withPeek];
    }
      
  /* check body */
  body = [info objectForKey: @"body"];
  if (body)
    {
      /* FIXME: this seems to generate bad mime part keys, which triggers a
         exceptions such as this:

         ERROR(-[NGImap4Client _processCommandParserException:]): catched
         IMAP4 parser exception NGImap4ParserException: unsupported fetch key:
         nil)

         Do we really need to assign p to sp in a multipart body part? Or do
         we need to do this only when the part in question is the first one in
         the message? */

      sp = [[body valueForKey: @"type"] lowercaseString];
      if ([sp isEqualToString: @"multipart"])
	sp = p;
      else
	sp = [p length] > 0 ? (id)[p stringByAppendingString: @".1"] : (id)@"1";
      [self addRequiredKeysOfStructure: body
	    path: sp toArray: keys
	    acceptedTypes: types
            withPeek: withPeek];
    }
}

- (NSArray *) plainTextContentFetchKeys
{
  /*
    The name is not 100% correct. The method returns all body structure fetch
    keys which are marked by the -shouldFetchPartOfType:subtype: method.
  */
  NSMutableArray *ma;
  NSArray *types;

  types = [NSArray arrayWithObjects: @"text/plain", @"text/html",
		   @"text/calendar", @"application/ics",
		   @"application/pgp-signature", nil];
  ma = [NSMutableArray arrayWithCapacity: 4];
  [self addRequiredKeysOfStructure: [self bodyStructure]
	path: @"" toArray: ma acceptedTypes: types
        withPeek: NO];

  return ma;
}

- (NSDictionary *) fetchPlainTextParts: (NSArray *) _fetchKeys
{
  // TODO: is the name correct or does it also fetch other parts?
  NSMutableDictionary *flatContents;
  unsigned i, count;
  NSArray *results;
  id result;
  
  [self debugWithFormat: @"fetch keys: %@", _fetchKeys];

  result = [self fetchParts: [_fetchKeys objectsForKey: @"key"
					 notFoundMarker: nil]];
  result = [result valueForKey: @"RawResponse"]; // hackish

  // Note: -valueForKey: doesn't work!
  results = [(NGHashMap *)result objectsForKey: @"fetch"];
  result = [results flattenedDictionaries];

  count        = [_fetchKeys count];
  flatContents = [NSMutableDictionary dictionaryWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSString *key;
    NSData   *data;
    
    key  = [[_fetchKeys objectAtIndex:i] objectForKey: @"key"];
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

- (NSDictionary *) fetchPlainTextParts
{
  return [self fetchPlainTextParts: [self plainTextContentFetchKeys]];
}

- (NSString *) _urlToPart: (NSDictionary *) infos
	       withPrefix: (NSString *) urlPrefix
{
  NSDictionary *parameters;
  NSString *urlToPart, *filename;

  parameters = [infos objectForKey: @"parameterList"];
  filename = [parameters objectForKey: @"name"];
  if (!filename)
    {
      parameters = [[infos objectForKey: @"disposition"]
		     objectForKey: @"parameterList"];
      filename = [parameters objectForKey: @"filename"];
    }

  if ([filename length])
    urlToPart = [NSString stringWithFormat: @"%@/%@", urlPrefix, filename];
  else
    urlToPart = urlPrefix;

  return urlToPart;
}

- (void) _feedAttachmentIds: (NSMutableDictionary *) attachmentIds
		  withInfos: (NSDictionary *) infos
		  andPrefix: (NSString *) prefix
{
  NSArray *parts;
  NSDictionary *currentPart;
  unsigned int count, max;
  NSString *url, *cid;

  cid = [infos objectForKey: @"bodyId"];
  if ([cid length])
    {
      url = [self _urlToPart: infos withPrefix: prefix];
      if (url)
	[attachmentIds setObject: url forKey: cid];
    }

  parts = [infos objectForKey: @"parts"];
  max = [parts count];
  for (count = 0; count < max; count++)
    {
      currentPart = [parts objectAtIndex: count];
      [self _feedAttachmentIds: attachmentIds
	    withInfos: currentPart
	    andPrefix: [NSString stringWithFormat: @"%@/%d",
				 prefix, count + 1]];
    }
}

- (NSDictionary *) fetchAttachmentIds
{
  NSMutableDictionary *attachmentIds;
  NSString *prefix;

  attachmentIds = [NSMutableDictionary dictionary];

  [self fetchCoreInfos];
  prefix = [[self soURL] absoluteString];
  if ([prefix hasSuffix: @"/"])
    prefix = [prefix substringToIndex: [prefix length] - 1];
  [self _feedAttachmentIds: attachmentIds
	withInfos: [coreInfos objectForKey: @"bodystructure"]
	andPrefix: prefix];

  return attachmentIds;
}

/* convert parts to strings */
- (NSString *) stringForData: (NSData *) _data
		    partInfo: (NSDictionary *) _info
{
  NSString *charset, *s;
  NSData *mailData;
  
  if ([_data isNotNull])
    {
      mailData
	= [_data bodyDataFromEncoding: [_info objectForKey: @"encoding"]];

      charset = [[_info valueForKey: @"parameterList"] valueForKey: @"charset"];
      if (![charset length])
	{
	  s = nil;
	}
      else
	{
	  s = [NSString stringWithData: mailData usingEncodingNamed: charset];
	}
      
      // If it has failed, we try at least using UTF-8. Normally, this can NOT fail.
      // Unfortunately, it seems to fail under GNUstep so we try latin1 if that's
      // the case
      if (!s)
	s = [[[NSString alloc] initWithData: mailData encoding: NSUTF8StringEncoding] autorelease];
      
      if (!s)
	s = [[[NSString alloc] initWithData: mailData encoding: NSISOLatin1StringEncoding] autorelease];
    }
  else
    s = nil;

  return s;
}

- (NSDictionary *) stringifyTextParts: (NSDictionary *) _datas
{
  NSMutableDictionary *md;
  NSDictionary *info;
  NSEnumerator *keys;
  NSString     *key, *s;

  md = [NSMutableDictionary dictionaryWithCapacity:4];
  keys = [_datas keyEnumerator];
  while ((key = [keys nextObject]))
    {
      info = [self lookupInfoForBodyPart: key];
      s = [self stringForData: [_datas objectForKey:key] partInfo: info];
      if (s)
	[md setObject: s forKey: key];
    }

  return md;
}

- (NSDictionary *) fetchPlainTextStrings: (NSArray *) _fetchKeys
{
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
  [coreInfos release];
  coreInfos = nil;
  return [[self imap4Connection] addFlags:_flags toURL: [self imap4URL]];
}

- (NSException *) removeFlags: (id) _flags
{
  [coreInfos release];
  coreInfos = nil;
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
  NSArray *parts;
  int part;
  NSDictionary *partDesc;
  NSString *mimeType;

  parts = [[self bodyStructure] objectForKey: @"parts"];

  /* We don't have parts here but we're trying to download the message's
     content that could be an image/jpeg, as an example */
  if ([parts count] == 0 && ![_key intValue])
    {
      partDesc = [self bodyStructure];
      _key = @"1";
    }
  else
    {
      part = [_key intValue] - 1;
      if (part > -1 && part < [parts count])
	partDesc = [parts objectAtIndex: part];
      else
	partDesc = nil;
    }

  if (partDesc)
    {
      mimeType = [[partDesc keysWithFormat: @"%{type}/%{subtype}"] lowercaseString];
      clazz = [SOGoMailBodyPart bodyPartClassForMimeType: mimeType
				inContext: _ctx];
    }
  else
    clazz = Nil;

  return [clazz objectWithName:_key inContainer: self];
}

- (id) lookupName: (NSString *) _key
	inContext: (id) _ctx
	  acquire: (BOOL) _flag
{
  id obj;
  
  /* first check attributes directly bound to the application */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]) != nil)
    return obj;
  
  /* lookup body part */
  
  if ([self isBodyPartKey:_key]) {
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

- (BOOL) davIsCollection
{
  /* while a mail has child objects, it should appear as a file in WebDAV */
  return NO;
}

- (NSString *) davContentLength
{
  return [[self fetchCoreInfos] valueForKey: @"size"];
}

- (NSDate *) davCreationDate
{
  // TODO: use INTERNALDATE once NGImap4 supports that
  return nil;
}

- (NSDate *) davLastModified
{
  return [self davCreationDate];
}

- (NSException *) davMoveToTargetObject: (id) _target
				newName: (NSString *) _name
			      inContext: (id)_ctx
{
  [self logWithFormat: @"TODO: should move mail as '%@' to: %@",
	_name, _target];
  return [NSException exceptionWithHTTPStatus: 501 /* Not Implemented */
		      reason: @"not implemented"];
}

- (NSException *) davCopyToTargetObject: (id) _target
				newName: (NSString *) _name
			      inContext: (id)_ctx
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
  NGImap4ConnectionManager *manager;
  NSException *exc;
  NSString *password;

  destImap4URL = ([_name length] == 0)
    ? [[_target container] imap4URL]
    : [_target imap4URL];

  manager = [self mailManager];
  [self imap4URL];
  password = [self imap4PasswordRenewed: NO];
  if (password)
    {
      exc = [manager copyMailURL: imap4URL
                     toFolderURL: destImap4URL
                        password: password];
      if (exc)
        {
          [self
            logWithFormat: @"failure. Attempting with renewed imap4 password"];
          password = [self imap4PasswordRenewed: YES];
          if (password)
            exc = [manager copyMailURL: imap4URL
                           toFolderURL: destImap4URL
                              password: password];
        }
    }
  else
    exc = nil;

  return exc;
}

/* actions */

- (id) GETAction: (id) _ctx
{
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

- (NSException *) copyToFolderNamed: (NSString *) folderName
                          inContext: (id)_ctx
{
  SOGoMailFolder *destFolder;
  NSEnumerator *folders;
  NSString *currentFolderName, *reason;

  // TODO: check for safe HTTP method

  destFolder = (SOGoMailFolder *) [self mailAccountsFolder];
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

  return [self davCopyToTargetObject: destFolder
	       newName: @"fakeNewUnusedByIMAP4" /* autoassigned */
	       inContext:_ctx];
}

- (NSException *) moveToFolderNamed: (NSString *) folderName
                          inContext: (id)_ctx
{
  NSException    *error;

  if (![self copyToFolderNamed: folderName
	     inContext: _ctx])
    {
      /* b) mark deleted */
  
      error = [[self imap4Connection] markURLDeleted: [self imap4URL]];
      if (error != nil) return error;

      [self flushMailCaches];
    }
  
  return nil;
}

- (NSException *) delete
{
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

- (id) DELETEAction: (id) _ctx
{
  NSException *error;
  
  // TODO: ensure safe HTTP method
  
  error = [[self imap4Connection] markURLDeleted:[self imap4URL]];
  if (error != nil) return error;
  
  error = [[self imap4Connection] expungeAtURL:[[self container] imap4URL]];
  if (error != nil) return error; // TODO: unflag as deleted?
  
  return [NSNumber numberWithBool:YES]; /* delete was successful */
}

/* some mail classification */

- (BOOL) isMailingListMail
{
  NSDictionary *h;
  
  if ((h = [self mailHeaders]) == nil)
    return NO;
  
  return [[h objectForKey: @"list-id"] isNotEmpty];
}

- (BOOL) isVirusScanned
{
  NSDictionary *h;
  
  if ((h = [self mailHeaders]) == nil)
    return NO;
  
  if (![[h objectForKey: @"x-virus-status"]  isNotEmpty]) return NO;
  if (![[h objectForKey: @"x-virus-scanned"] isNotEmpty]) return NO;
  return YES;
}

- (NSString *) scanListHeaderValue: (id) _value
		forFieldWithPrefix: (NSString *) _prefix
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

- (NSString *) mailingListArchiveURL
{
  return [self scanListHeaderValue:
		 [[self mailHeaders] objectForKey: @"list-archive"]
	       forFieldWithPrefix: @"<http://"];
}

- (NSString *) mailingListSubscribeURL
{
  return [self scanListHeaderValue:
		 [[self mailHeaders] objectForKey: @"list-subscribe"]
	       forFieldWithPrefix: @"<http://"];
}

- (NSString *) mailingListUnsubscribeURL
{
  return [self scanListHeaderValue:
		 [[self mailHeaders] objectForKey: @"list-unsubscribe"]
	       forFieldWithPrefix: @"<http://"];
}

/* etag support */

- (id) davEntityTag
{
  /*
    Note: There is one thing which *can* change for an existing message,
          those are the IMAP4 flags (and annotations, which we do not use).
	  Since we don't render the flags, it should be OK, if this changes
	  we must embed the flagging into the etag.
  */
  return mailETag;
}

- (int) zlGenerationCount
{
  return 0; /* mails never change */
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return [container aclsForUser: uid];
}

/* debugging */

- (BOOL) isDebuggingEnabled
{
  return debugOn;
}


// For DAV PUT
- (id) PUTAction: (WOContext *) _ctx
{
  WORequest *rq;
  NSException *error;
  WOResponse *response;
  SOGoMailFolder *folder;
  int imap4id;

  error = [self matchesRequestConditionInContext: _ctx];
  if (error)
    response = (WOResponse *) error;
  else
    {
      rq = [_ctx request];
      folder = [self container];

      if ([self doesMailExist])
        response = [NSException exceptionWithHTTPStatus: 403
                                                 reason: @"Can't overwrite messages"];
      else
        response = [folder appendMessage: [rq content]
                                 usingId: &imap4id];
    }

  return response;
}

// For DAV REPORT
- (id) _fetchProperty: (NSString *) property
{
  NSArray *parts;
  id rc, msgs;

  rc = nil;

  if (property)
    {
      parts = [NSArray arrayWithObject: property];
      
      msgs = [self fetchParts: parts];
      msgs = [msgs valueForKey: @"fetch"];
      if ([msgs count]) {
          rc = [msgs objectAtIndex: 0];
      }
    }

  return rc;
}

- (BOOL) _hasFlag: (NSString *) flag
{
  BOOL rc;
  NSArray *flags;

  flags = [[self fetchCoreInfos] objectForKey: @"flags"];
  rc = [flags containsObject: flag];

  return rc;
}

- (NSString *) _emailAddressesFrom: (NSArray *) enveloppeAddresses
{
  NSMutableArray *addresses;
  NSString *rc;
  NGImap4EnvelopeAddress *address;
  NSString *email;
  int count, max;

  rc = nil;
  max = [enveloppeAddresses count];

  if (max > 0)
    {
      addresses = [NSMutableArray array];
      for (count = 0; count < max; count++)
        {
          address = [enveloppeAddresses objectAtIndex: count];
          email = [NSString stringWithFormat: @"%@", [address email]];

          [addresses addObject: email];
        }
      rc = [addresses componentsJoinedByString: @", "];
    }

  return rc;
}

// Properties

//{urn:schemas:httpmail:}

// date already exists, but this one is the correct format
- (NSString *) davDate
{
  return [[self date] rfc822DateString]; 
}

- (BOOL) hasAttachment
{
  return ([[self fetchAttachmentIds] count] > 0);
}

- (BOOL) isNewMail
{
  return [self _hasFlag: @"recent"];
}

- (BOOL) read
{
  return [self _hasFlag: @"seen"];
}

- (BOOL) replied
{
  return [self _hasFlag: @"answered"];
}

- (BOOL) forwarded
{
  return [self _hasFlag: @"$forwarded"];
}

- (BOOL) deleted
{
  return [self _hasFlag: @"deleted"];
}

- (NSString *) textDescription
{
#warning We should send the content as an NSData
  return [NSString stringWithFormat: @"<![CDATA[%@]]>", [self contentAsString]];
}


//{urn:schemas:mailheader:}

- (NSString *) to
{
  return [self _emailAddressesFrom: [self toEnvelopeAddresses]];
}

- (NSString *) cc
{
  return [self _emailAddressesFrom: [self ccEnvelopeAddresses]];
}

- (NSString *) from
{
  return [self _emailAddressesFrom: [self fromEnvelopeAddresses]];
}

- (NSString *) inReplyTo
{
  return [[self envelope] inReplyTo];
}

- (NSString *) messageId
{
  return [[self envelope] messageID];
}

- (NSString *) received
{
  NSDictionary *fetch;
  NSData *data;
  NSString *value, *rc;
  NSRange range;

  rc = nil;
  fetch = [self _fetchProperty: @"BODY[HEADER.FIELDS (RECEIVED)]"];

  if ([fetch count])
    {
      data = [fetch objectForKey: @"header"];
      value = [[NSString alloc] initWithData: data 
                                    encoding: NSUTF8StringEncoding];
      range = [value rangeOfString: @"received:"
                           options: NSCaseInsensitiveSearch
                             range: NSMakeRange (10, [value length] - 11)];
      if (range.length 
          && range.location < [value length]
          && range.length < [value length])
        {
          // We want to keep the first part
          range.length = range.location;
          range.location = 0;
          rc = [[value substringWithRange: range] stringByTrimmingSpaces];
        }
      else
        rc = [value stringByTrimmingSpaces];

      [value release];
    }

  return rc;
}

- (NSString *) references
{
  NSDictionary *fetch;
  NSData *data;
  NSString *value, *rc;

  rc = nil;
  fetch = [self _fetchProperty: @"BODY[HEADER.FIELDS (REFERENCES)]"];

  if ([fetch count])
    {
      data = [fetch objectForKey: @"header"];
      value = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
      if (value && [value length] > 11)
        rc = [[value substringFromIndex: 11] stringByTrimmingSpaces];
      [value release];
    }

  return rc;
}

- (NSString *) davDisplayName
{
  return [self subject];
}

@end /* SOGoMailObject */
