/*
  Copyright (C) 2021 Inverse inc.

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeFileData.h>
#import <NGMime/NGMimeHeaderFields.h>
#import <NGMime/NGMimeMultipartBody.h>

#import <SOGo/RTFHandler.h>

#import <SoObjects/Mailer/NSData+SMIME.h>

#import <ytnef.h>

#import "SOGoTnefMailBodyPart.h"

/*
  SOGoTnefMailBodyPart

  A specialized SOGoMailBodyPart subclass for application/ms-tnef attachments. Can
  be used to attach special SoMethods.

  See the superclass for more information on part objects.
*/

@implementation SOGoTnefMailBodyPart

/* Overwritten methods */

- (id) init
{
  if ((self = [super init]))
    {
      part = nil;
      filename = nil;
      bodyParts = [[NGMimeMultipartBody alloc] init];
      [bodyParts retain];
    }

  return self;
}

- (id) initWithName: (NSString *) _name
        inContainer: (id) _container
{
  self = [super initWithName: _name inContainer: _container];

  [self decodeBLOB];

  return self;
}

- (void) dealloc
{
  [part release];
  [filename release];
  [bodyParts release];

  [super dealloc];
}

- (id) lookupName: (NSString *) _key
	inContext: (id) _ctx
	  acquire: (BOOL) _flag
{
  NSArray *parts;
  int i;

  if ([self isBodyPartKey: _key])
    {
      // _key is an integer
      parts = [bodyParts parts];
      i = [_key intValue] - 1;

      if (i > -1 && i < [parts count])
        {
          [self setPart: [parts objectAtIndex: i]];
          return self;
        }
    }
  else if ([_key isEqualToString: [self filename]])
    {
      return self;
    }
  else if ([_key isEqualToString: @"asAttachment"])
    {
      [self setAsAttachment];
      return self;
    }

  /* Fallback to super class */
  return [super lookupName: _key inContext: _ctx acquire: _flag];
}

- (NSData *) fetchBLOB
{
  if (part)
    return [part body];

  return [super fetchBLOB];
}

- (NSString *) filename
{
  if (filename)
    return filename;
  else if (part)
    return nil; // don't try to fetch the filename from the IMAP body structure
  else
    return [super filename];
}

- (id) partInfo
{
  if (partInfo)
    return partInfo;
  else if (part)
    return nil; // don't try to fetch the info from the IMAP body structure
  else
    return [super partInfo];
}

/* New methods */

- (NGMimeMultipartBody *) bodyParts
{
  return bodyParts;
}

- (void) decodeBLOB
{
  NSData *data;
  NSString *partName, *type, *subtype;
  variableLength *attachmentName;
  variableLength *filedata;

  [self setPart: nil];
  partName = nil;
  data = [self fetchBLOB];

  DWORD signature;
  memcpy(&signature, [data bytes], sizeof(DWORD));
  if (TNEFCheckForSignature(signature) == 0)
    {
      TNEFStruct tnef;

      TNEFInitialize(&tnef);
      tnef.Debug = 0;
      if (TNEFParseMemory((unsigned char *)[data bytes], [data length], &tnef) != -1)
        {
          // unsigned int count = 0;

          if (strcmp((char *)tnef.messageClass, "IPM.Microsoft Mail.Note") == 0)
            {
              if (tnef.subject.size > 0)
                {
                  filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_BINARY, PR_BODY_HTML));
                  if (filedata != MAPI_UNDEFINED)
                    {
                      // count++;
                      partName = [NSString stringWithFormat: @"%s.html", tnef.subject.data];
                      data = [NSData dataWithBytes: filedata->data length: filedata->size];
                    }
                  else
                    {
                      filedata = MAPIFindProperty(&(tnef.MapiProperties), PROP_TAG(PT_BINARY, PR_RTF_COMPRESSED));
                      if (filedata != MAPI_UNDEFINED)
                        {
                          RTFHandler *handler;
                          variableLength buf;
                          buf.data = DecompressRTF(filedata, &(buf.size));
                          if (buf.data != NULL)
                            {
                              // count++;
                              partName = [NSString stringWithFormat: @"%s.html", tnef.subject.data];
                              data = [NSData dataWithBytes: buf.data length: buf.size];

                              handler = [[RTFHandler alloc] initWithData: data];
                              AUTORELEASE(handler);
                              data = [handler parse]; // RTF to HTML
                            }
                        }
                    }

                  if ([data length])
                    {
                      [self bodyPartForData: data
                                   withType: @"text"
                                 andSubtype: @"html"];
                    }
                }
            }
          // Other classes to handle:
          //
          //   IPM.Contact
          //   IPM.Task
          //   IPM.Microsoft Schedule.MtgReq
          //   IPM.Appointment
          //

          Attachment *p;
          BOOL isObject, isRealAttachment;

          p = tnef.starting_attach.next;
          while (p != NULL)
            {
              if (p->FileData.size > 0)
                {
                  isObject = YES;

                  // See if the contents are stored as "attached data" inside the MAPI blocks.
                  filedata = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_OBJECT, PR_ATTACH_DATA_OBJ));
                  if (filedata == MAPI_UNDEFINED)
                    {
                      // Nope, standard TNEF stuff.
                      filedata = &(p->FileData);
                      isObject = NO;
                    }

                  // See if this is an embedded TNEF stream.
                  isRealAttachment = YES;

                  TNEFStruct emb_tnef;
                  DWORD signature;

                  if (isObject)
                    {
                      // This is an "embedded object", so skip the 16-byte identifier first.
                      memcpy(&signature, filedata->data + 16, sizeof(DWORD));
                      if (TNEFCheckForSignature(signature) == 0) {
                        TNEFInitialize(&emb_tnef);
                        emb_tnef.Debug = tnef.Debug;
                        if (TNEFParseMemory(filedata->data + 16, filedata->size - 16, &emb_tnef) != -1)
                          {
                            isRealAttachment = NO;
                          }
                        TNEFFree(&emb_tnef);
                      }
                    }
                  else
                    {
                      memcpy(&signature, filedata->data, sizeof(DWORD));
                      if (TNEFCheckForSignature(signature) == 0) {
                        TNEFInitialize(&emb_tnef);
                        emb_tnef.Debug = tnef.Debug;
                        if (TNEFParseMemory(filedata->data, filedata->size, &emb_tnef) != -1)
                          {
                            isRealAttachment = NO;
                          }
                        TNEFFree(&emb_tnef);
                      }
                    }
                  if (isRealAttachment)
                    {
                      // Ok, it's not an embedded stream, so now we process it.
                      attachmentName = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_STRING8, PR_ATTACH_LONG_FILENAME));
                      if (attachmentName == MAPI_UNDEFINED)
                        {
                          attachmentName = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_STRING8, PR_DISPLAY_NAME));
                          if (attachmentName == MAPI_UNDEFINED)
                            {
                              attachmentName = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_STRING8, PR_ATTACH_TRANSPORT_NAME));
                              if (attachmentName == MAPI_UNDEFINED)
                                {
                                  attachmentName = &(p->Title);
                                }
                            }
                        }

                      // MAPIPrint(&p->MAPI);

                      variableLength *prop;

                      if (attachmentName->size > 1)
                        {
                          partName = [NSString stringWithUTF8String: attachmentName->data];

                          type = @"application";
                          subtype = @"octet-stream";

                          prop = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_UNICODE, PR_ATTACH_MIME_TAG));
                          if (prop != MAPI_UNDEFINED)
                            {
                              NSString *mime = [NSString stringWithUTF8String: prop->data];
                              NSArray *pair = [mime componentsSeparatedByString: @"/"];
                              if ([pair count] == 2)
                                {
                                  type = [pair objectAtIndex: 0];
                                  subtype = [pair objectAtIndex: 1];
                                }
                              else
                                {
                                  [self warnWithFormat: @"Unexpected MIME type %@", mime];
                                }
                            }
                          else
                            {
                              prop = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_STRING8, PR_ATTACH_EXTENSION));
                              if (prop != MAPI_UNDEFINED)
                                {
                                  NSString *ext = [NSString stringWithUTF8String: prop->data];
                                  if ([ext caseInsensitiveCompare: @".txt"] == NSOrderedSame)
                                    {
                                      type = @"text";
                                      subtype = @"plain";
                                    }
                                  else
                                    {
                                      [self warnWithFormat: @"Unidentified extension %@", ext];
                                    }
                                }
                            }

                          NSString *cid = partName;
                          prop = MAPIFindProperty(&(p->MAPI), PROP_TAG(PT_UNICODE, 0x3712)); // PR_CONTENT_IDENTIFIER?
                          if (prop != MAPI_UNDEFINED)
                            {
                              cid = [NSString stringWithUTF8String: prop->data];
                            }

                          NSData *attachment;
                          if (isObject)
                            attachment = [NSData dataWithBytes: filedata->data + 16 length: filedata->size - 16];
                          else
                            attachment = [NSData dataWithBytes: filedata->data length: filedata->size];

                          [self bodyPartForAttachment: attachment
                                             withName: partName
                                              andType: type
                                           andSubtype: subtype
                                         andContentId: cid];

                          // count++;
                        }
                    } // if isRealAttachment
                } // if size>0
              p = p->next;
            }
        }
      TNEFFree(&tnef);
    }
}

- (void) setPart: (NGMimeBodyPart *) newPart
{
  ASSIGN (part, newPart);
  if (newPart)
    {
      [self setFilename: [[newPart bodyInfo] filename]];
      [self setPartInfo: [newPart bodyInfo]];
    }
  else
    {
      [self setFilename: nil];
      [self setPartInfo: nil];
    }
}

- (void) setFilename: (NSString *) newFilename
{
  ASSIGN (filename, newFilename);
}

- (void) setPartInfo: (id) newPartInfo
{
  ASSIGN (partInfo, newPartInfo);
}

- (NSString *) contentDispositionForAttachmentWithName: (NSString *) _name
                                               andSize: (NSNumber *) _size
                                        andContentType: (NSString *) _type
{
  NSString *cdtype, *cd;

  if (([_type caseInsensitiveCompare: @"image"]    == NSOrderedSame) ||
      ([_type caseInsensitiveCompare: @"message"]  == NSOrderedSame))
    cdtype = @"inline";
  else
    cdtype = @"attachment";

  cd = [NSString stringWithFormat: @"%@; filename=\"%@\"; size=%i;",
                 cdtype, [_name stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""], [_size intValue]];

  return cd;
}

- (NGMimeBodyPart *) bodyPartForData: (NSData *)   _data
                            withType: (NSString *) _type
                          andSubtype: (NSString *) _subtype
{
  NGMutableHashMap *map;
  NGMimeBodyPart   *bodyPart;
  NSData           *content;
  id                body;

  if (_data == nil) return nil;

  /* check attachment */

  /* prepare header of body part */

  map = [[[NGMutableHashMap alloc] initWithCapacity: 4] autorelease];

  // Content-Type
  [map setObject: [NSString stringWithFormat: @"%@/%@", _type, _subtype]
          forKey: @"content-type"];

  /* prepare body content */

  content = [NSData dataWithBytes: [_data bytes] length: [_data length]];
  [map setObject: [NSNumber numberWithInt: [content length]]
          forKey: @"content-length"];

  /* Note: the -init method will create a temporary file! */
  body = [[[NGMimeFileData alloc] initWithBytes: [content bytes]
                                         length: [content length]] autorelease];

  bodyPart = [[[NGMimeBodyPart alloc] initWithHeader: map] autorelease];
  [bodyPart setBody: body];
  [bodyParts addBodyPart: bodyPart];

  return bodyPart;
}

- (NGMimeBodyPart *) bodyPartForAttachment: (NSData *)   _data
                                  withName: (NSString *) _name
                                   andType: (NSString *) _type
                                andSubtype: (NSString *) _subtype
                              andContentId: (NSString *) _cid
{
  NGMutableHashMap *map;
  NGMimeBodyPart   *bodyPart;
  NSData           *content;
  NSString         *s;
  id body;

  if (_name == nil) return nil;

  /* prepare header of body part */

  map = [[[NGMutableHashMap alloc] initWithCapacity: 4] autorelease];

  // Content-Type
  [map setObject: [NSString stringWithFormat: @"%@/%@", _type, _subtype]
          forKey: @"content-type"];

  // Content-Id
  [map setObject: _cid
          forKey: @"content-id"];

  // Content-Disposition
  s = [self contentDispositionForAttachmentWithName: _name
                                            andSize: [NSNumber numberWithLong: [_data length]]
                                     andContentType: _type];
  NGMimeContentDispositionHeaderField *o;
  o = [[NGMimeContentDispositionHeaderField alloc] initWithString: s];
  [map setObject: o forKey: @"content-disposition"];
  [o release];

  /* prepare body content */

  content = [NSData dataWithBytes: [_data bytes] length: [_data length]];
  [map setObject: [NSNumber numberWithInt: [content length]]
          forKey: @"content-length"];

  /* Note: the -init method will create a temporary file! */
  body = [[NGMimeFileData alloc] initWithBytes: [content bytes]
                                        length: [content length]];

  bodyPart = [[[NGMimeBodyPart alloc] initWithHeader: map] autorelease];
  [bodyPart setBody: body];

  [body release];
  [bodyParts addBodyPart: bodyPart];

  return bodyPart;
}

@end /* SOGoTnefMailBodyPart */
