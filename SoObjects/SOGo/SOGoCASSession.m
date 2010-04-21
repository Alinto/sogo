/* SOGoCASSession.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSURL.h>

#import <DOM/DOMElement.h>
#import <DOM/DOMDocument.h>
#import <DOM/DOMProtocols.h>
#import <DOM/DOMText.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOHTTPConnection.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>

#import "NSDictionary+BSJSONAdditions.h"
#import "NSString+Utilities.h"
#import "SOGoCache.h"
#import "SOGoObject.h"
#import "SOGoSystemDefaults.h"

#import "SOGoCASSession.h"

@implementation SOGoCASSession

+ (NSString *) CASURLWithAction: (NSString *) casAction
                  andParameters: (NSDictionary *) parameters
{
  NSString *casActionURL, *baseCASURL;
  SOGoSystemDefaults *sd;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  baseCASURL = [sd CASServiceURL];
  if ([baseCASURL length])
    casActionURL = [baseCASURL composeURLWithAction: casAction
                                         parameters: parameters
                                            andHash: NO];
  else
    {
      [self errorWithFormat:
              @"'SOGoCASServiceURL' is empty in the user defaults"];
      casActionURL = nil;
    }

  return casActionURL;
}

+ (SOGoCASSession *) CASSessionWithTicket: (NSString *) newTicket
{
  SOGoCASSession *newSession;

  if (newTicket)
    {
      newSession = [self new];
      [newSession autorelease];
      [newSession setTicket: newTicket];
    }
  else
    newSession = nil;

  return newSession;
}

+ (SOGoCASSession *) CASSessionWithIdentifier: (NSString *) identifier
{
  SOGoCASSession *session;
  SOGoCache *cache;
  NSString *casTicket;

  cache = [SOGoCache sharedCache];
  casTicket = [cache CASTicketFromIdentifier: identifier];
  session = [self CASSessionWithTicket: casTicket];

  return session;
}

- (id) init
{
  if ((self = [super init]))
    {
      ticket = nil;
      login = nil;
      pgt = nil;
      identifier = nil;
      proxyTickets = nil;
      cacheUpdateNeeded = NO;
    }

  return self;
}

- (void) dealloc
{
  [login release];
  [pgt release];
  [ticket release];
  [proxyTickets release];
  [super dealloc];
}

- (void) _loadSessionFromCache
{
  SOGoCache *cache;
  NSString *jsonSession;
  NSDictionary *sessionDict;

  cache = [SOGoCache sharedCache];
  jsonSession = [cache CASSessionWithTicket: ticket];
  if ([jsonSession length])
    {
      sessionDict = [NSMutableDictionary dictionaryWithJSONString: jsonSession];
      ASSIGN (login, [sessionDict objectForKey: @"login"]);
      ASSIGN (pgt, [sessionDict objectForKey: @"pgt"]);
      ASSIGN (identifier, [sessionDict objectForKey: @"identifier"]);
      ASSIGN (proxyTickets, [sessionDict objectForKey: @"proxyTickets"]);
      if (!proxyTickets)
        proxyTickets = [NSMutableDictionary new];
    }
  else
    cacheUpdateNeeded = YES;
}

- (void) _saveSessionToCache
{
  SOGoCache *cache;
  NSString *jsonSession;
  NSMutableDictionary *sessionDict;

  cache = [SOGoCache sharedCache];
  sessionDict = [NSMutableDictionary dictionary];
  [sessionDict setObject: login forKey: @"login"];
  if (pgt)
    [sessionDict setObject: pgt forKey: @"pgt"];
  [sessionDict setObject: identifier forKey: @"identifier"];
  if ([proxyTickets count])
    [sessionDict setObject: proxyTickets forKey: @"proxyTickets"];
  jsonSession = [sessionDict jsonStringValue];
  [cache setCASSession: jsonSession
            withTicket: ticket
         forIdentifier: identifier];
}

- (void) setTicket: (NSString *) newTicket
{
  ASSIGN (ticket, newTicket);
  [self _loadSessionFromCache];
}

- (NSString *) ticket
{
  return ticket;
}

- (void) _parseSuccessElement: (NGDOMElement *) element
{
  NSString *tagName, *pgtIou;
  NGDOMText *valueNode;
  SOGoCache *cache;

  tagName = [element tagName];
  valueNode = (NGDOMText *) [element firstChild];
  if ([valueNode nodeType] == DOM_TEXT_NODE)
    {
      if ([tagName isEqualToString: @"user"])
        ASSIGN (login, [valueNode nodeValue]);
      else if ([tagName isEqualToString: @"proxyGrantingTicket"])
        {
          pgtIou = [valueNode nodeValue];
          cache = [SOGoCache sharedCache];
          ASSIGN (pgt, [cache CASPGTIdFromPGTIOU: pgtIou]);
        }
      else
        [self logWithFormat: @"unhandled success tag '%@'", tagName];
    }
}

- (void) _parseProxySuccessElement: (NGDOMElement *) element
{
  NSString *tagName;
  NGDOMText *valueNode;

  tagName = [element tagName];
  if ([tagName isEqualToString: @"proxyTicket"])
    {
      valueNode = (NGDOMText *) [element firstChild];
      if ([valueNode nodeType] == DOM_TEXT_NODE)
        {
          [proxyTickets setObject: [valueNode nodeValue]
                           forKey: currentProxyService];
          cacheUpdateNeeded = YES;
        }
    }
  else
    [self logWithFormat: @"unhandled proxy success tag '%@'", tagName];
}

- (void) _parseProxyFailureElement: (NGDOMElement *) element
{
  NSMutableString *errorString;
  NSString *errorText;
  NGDOMText *valueNode;

  errorString = [NSMutableString stringWithString: (@"a CAS failure occured"
                                                    @" during operation")];
  if ([element hasAttribute: @"code"])
    [errorString appendFormat: @" (code: '%@')",
           [element attribute: @"code"]];
  valueNode = (NGDOMText *) [element firstChild];
  if (valueNode)
    {
      [errorString appendString: @":"];
      while (valueNode)
        {
          if ([valueNode nodeType] == DOM_TEXT_NODE)
            {
              errorText = [[valueNode nodeValue] stringByTrimmingSpaces];
              [errorString appendFormat: @" %@", errorText];
            }
          valueNode = (NGDOMText *) [valueNode nextSibling];
        }
    }

  [self logWithFormat: errorString];
}

- (SEL) _selectorForSubElementsOfTag: (NSString *) tag
{
  static NSMutableDictionary *mapping = nil;
  NSString *methodName;
  SEL selector;

  if (!mapping)
    {
      mapping = [NSMutableDictionary new];
      [mapping setObject: @"_parseSuccessElement:"
                  forKey: @"authenticationSuccess"];
      [mapping setObject: @"_parseProxySuccessElement:"
                  forKey: @"proxySuccess"];
    }

  methodName = [mapping objectForKey: tag];
  if (methodName)
    selector = NSSelectorFromString (methodName);
  else
    {
      selector = NULL;
      [self errorWithFormat: @"unhandled response tag '%@'", tag];
    }

  return selector;
}

- (void) _parseResponseElement: (NGDOMElement *) element
{
  id <DOMNodeList> nodes;
  NGDOMElement *currentNode;
  SEL parseElementSelector;
  NSString *tagName;
  int count, max;

  tagName = [element tagName];
  if ([tagName isEqualToString: @"proxyFailure"])
    [self _parseProxyFailureElement: element];
  else
    {
      parseElementSelector = [self _selectorForSubElementsOfTag: tagName];
      if (parseElementSelector)
        {
          nodes = [element childNodes];
          max = [nodes length];
          for (count = 0; count < max; count++)
            {
              currentNode = [nodes objectAtIndex: count];
              if ([currentNode nodeType] == DOM_ELEMENT_NODE)
                [self performSelector: parseElementSelector
                           withObject: currentNode];
            }
        }
    }
}

- (void) _parseDOMResponse: (NGDOMDocument *) response
{
  id <DOMNodeList> nodes;
  NGDOMElement *currentNode;
  int count, max;

  nodes = [[response documentElement] childNodes];
  max = [nodes length];
  for (count = 0; count < max; count++)
    {
      currentNode = [nodes objectAtIndex: count];
      if ([currentNode nodeType] == DOM_ELEMENT_NODE)
        [self _parseResponseElement: currentNode];
    }
}

- (void) _performCASRequestWithAction: (NSString *) casAction
                        andParameters: (NSDictionary *) parameters
{
  NSString *requestURL;
  NSURL *url;
  WORequest *request;
  WOResponse *response;
  WOHTTPConnection *httpConnection;

  requestURL = [[self class] CASURLWithAction: casAction
                                andParameters: parameters];
  if (requestURL)
    {
      url = [NSURL URLWithString: requestURL];
      httpConnection = [[WOHTTPConnection alloc]
                         initWithURL: url];
      [httpConnection autorelease];
      request = [[WORequest alloc] initWithMethod: @"GET"
                                              uri: [requestURL hostlessURL]
                                      httpVersion: @"HTTP/1.1"
                                          headers: nil content: nil
                                         userInfo: nil];
      [request autorelease];
      [httpConnection sendRequest: request];
      response = [httpConnection readResponse];
      [self _parseDOMResponse: [response contentAsDOMDocument]];
    }
}

/* returns the URL that matches -[SOGoRootPage casProxyAction] */
- (NSString *) _pgtUrlFromURL: (NSURL *) soURL
{
  WOApplication *application;
  NSString *pgtURL;
  WORequest *request;

  application = [WOApplication application];
  request = [[application context] request];
  pgtURL = [NSString stringWithFormat:
                              @"https://%@/%@/casProxy",
                     [soURL host], [request applicationName]];

  return pgtURL;
}

- (void) _fetchTicketData
{
  NSDictionary *params;
  NSURL *soURL;
  NSString *serviceURL;

  soURL = [[WOApplication application] soURL];
  serviceURL = [soURL absoluteString];

  params = [NSDictionary dictionaryWithObjectsAndKeys:
                           ticket, @"ticket", serviceURL, @"service",
                                 [self _pgtUrlFromURL: soURL], @"pgtUrl",
                         nil];
  [self _performCASRequestWithAction: @"serviceValidate"
                       andParameters: params];
  identifier = [SOGoObject globallyUniqueObjectId];
  [identifier retain];
  if (![pgt length])
    [self warnWithFormat: @"failure to obtain a PGT from the C.A.S. service"];

  cacheUpdateNeeded = YES;
}

- (NSString *) login
{
  if (!login)
    [self _fetchTicketData];

  return login;
}

- (NSString *) identifier
{
  return identifier;
}

- (void) updateCache
{
  if (cacheUpdateNeeded)
    {
      [self _saveSessionToCache];
      cacheUpdateNeeded = NO;
    }
}

- (void) _fetchTicketDataForService: (NSString *) service
{
  NSDictionary *params;

  params = [NSDictionary dictionaryWithObjectsAndKeys:
                           pgt, @"pgt", service, @"targetService",
                         nil];
  [self _performCASRequestWithAction: @"proxy"
                       andParameters: params];
}

- (NSString *) ticketForService: (NSString *) service
{
  NSString *proxyTicket;

  if (pgt)
    {
      proxyTicket = [proxyTickets objectForKey: service];
      if (!proxyTicket)
        {
          currentProxyService = service;
          [self _fetchTicketDataForService: service];
          proxyTicket = [proxyTickets objectForKey: service];
          if (proxyTicket)
            cacheUpdateNeeded = YES;
          currentProxyService = nil;
        }
    }
  else
    {
      [self errorWithFormat: @"attempted to obtain a ticket for service '%@'"
            @" while no PGT available", service];
      proxyTicket = nil;
    }

  return proxyTicket;
}

- (void) invalidateTicketForService: (NSString *) service
{
  [proxyTickets removeObjectForKey: service];
  cacheUpdateNeeded = YES;
}

@end
