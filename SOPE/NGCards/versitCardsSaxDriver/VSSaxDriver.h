/*
 Copyright (C) 2003-2004 Max Berger
 Copyright (C) 2004-2005 OpenGroupware.org
 
 This file is part of versitCardsSaxDriver, written for the OpenGroupware.org 
 project (OGo).
 
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

#ifndef __versitCardsSaxDriver_VSSaxDriver_H__
#define __versitCardsSaxDriver_VSSaxDriver_H__

#import <Foundation/NSObject.h>
#include <SaxObjC/SaxXMLReader.h>

@class NSString, NSSet, NSDictionary, NSMutableArray, NSMutableDictionary;

@interface VSSaxDriver : NSObject < SaxXMLReader > 
{
  id<NSObject,SaxContentHandler> contentHandler;
  id<NSObject,SaxErrorHandler>   errorHandler;
  NSString                       *prefixURI;
  NSMutableArray                 *cardStack;
  NSMutableArray                 *elementList; /* a list of tags to be rep. */
  
  NSSet                          *attributeElements;
}

- (void)setPrefixURI:(NSString*)_uri;
- (NSString *)prefixURI;

/* events */

- (void)reportDocStart;
- (void)reportDocEnd;

@end

#endif /* __versitCardsSaxDriver_VersitCardsSaxDriver_H__ */
