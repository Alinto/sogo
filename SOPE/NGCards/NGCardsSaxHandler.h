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

#ifndef __NGiCal_NGCardsSaxHandler_H__
#define __NGiCal_NGCardsSaxHandler_H__

#include <SaxObjC/SaxDefaultHandler.h>

/*
  NGCardsSaxHandler
  
  This SAX handler is supposed to create the NGiCal object model from SAX
  events.
*/

@class NSString, NSMutableString, NSMutableArray;
@class NSDictionary, NSMutableDictionary;

@class CardElement;
@class CardGroup;

@interface NGCardsSaxHandler : SaxDefaultHandler
{
  unichar  *content;

  NSMutableArray *cards;

  CardElement *currentElement;
  CardGroup *currentCardGroup;

  NSString *currentGroup;
  unsigned contentLength;

  NSMutableArray      *types;

  struct {
    int isInVCardSet:1;
    int isInVCard:1;
    int isInGroup:1;
    int collectContent:1;
  } vcs;

  Class topGroupClass;
}

/* results */

- (NSArray *) cards;
- (void)reset;

/* content */

- (void) startCollectingContent;
- (NSArray *) finishCollectingContent;

- (void) startGroupElement: (NSString *) _localName;
- (void) endGroupElement;

- (void) setTopElementClass: (Class) aGroupClass;

@end

#endif /* __NGiCal_NGCardsSaxHandler_H__ */
