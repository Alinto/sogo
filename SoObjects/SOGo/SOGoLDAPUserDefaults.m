/* SOGoLDAPUserDefaults.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
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

#define LDAP_DEPRECATED	1

#import <ldap.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>

#import "SOGoLDAPUserDefaults.h"

#define SOGoLDAPDescriptor @"/etc/sogo.conf"
#define SOGoLDAPContainerSize 64

typedef enum _SOGoLDAPValueType {
  SOGoLDAPAtom,
  SOGoLDAPArray,
  SOGoLDAPDictionary,
  SOGoLDAPLastType
} _SOGoLDAPValueType;

typedef struct _SOGoLDAPValue {
  _SOGoLDAPValueType type;
  void *value;
  unsigned int maxCount;
  char *key;
} _SOGoLDAPValue;

@implementation SOGoLDAPUserDefaults

static _SOGoLDAPValue*
_createAtom (_SOGoLDAPValueType type, void *value)
{
  _SOGoLDAPValue *newAtom;

  newAtom = calloc (sizeof (_SOGoLDAPValue), 1);
  newAtom->type = type;
  newAtom->value = value;

  return newAtom;
}

static _SOGoLDAPValue*
_createContainer (_SOGoLDAPValueType type)
{
  _SOGoLDAPValue *newContainer;
  _SOGoLDAPValue **array;

  array = malloc (sizeof (_SOGoLDAPValue *) * SOGoLDAPContainerSize);
  *array = NULL;
  newContainer = _createAtom (type, array);
  newContainer->maxCount = SOGoLDAPContainerSize - 1; /* all values + NULL */

  return newContainer;
}

static void
_appendAtomToContainer (_SOGoLDAPValue *atom, _SOGoLDAPValue *container)
{
  unsigned int count;
  _SOGoLDAPValue **atoms, **currentAtom;

  atoms = (_SOGoLDAPValue **) container->value;
  currentAtom = atoms;
  while (*currentAtom)
    currentAtom++;

  count = (currentAtom - atoms);
  if (count > container->maxCount)
    {
      container->maxCount += SOGoLDAPContainerSize;
      container->value = realloc (container->value, container->maxCount + 1);
    }
  *currentAtom = atom;
  *(currentAtom + 1) = NULL;
}

static _SOGoLDAPValue **
_findAtomInDictionary (const char *key, const _SOGoLDAPValue *dictionary)
{
  _SOGoLDAPValue **atom, **value;

  atom = NULL;

  value = dictionary->value;
  if (value)
    {
      while (!atom && *value)
	if (strcmp ((*value)->key, key) == 0)
	  atom = value;
	else
	  value++;
    }

  return atom;
}

static void
_appendAtomToDictionary (_SOGoLDAPValue *atom, _SOGoLDAPValue *dictionary)
{
  _SOGoLDAPValue **oldAtomPtr, *oldAtom, *container;

  oldAtomPtr = _findAtomInDictionary (atom->key, dictionary);
  if (oldAtomPtr)
    {
      oldAtom = *oldAtomPtr;
      if (oldAtom->type == SOGoLDAPAtom)
	{
	  container = _createContainer (SOGoLDAPArray);
	  container->key = oldAtom->key;
	  oldAtom->key = NULL;
	  _appendAtomToContainer (oldAtom, container);
	  *oldAtomPtr = container;
	}
      else if (oldAtom->type == SOGoLDAPArray)
	container = oldAtom;
      else
	{
// 	  some error handling here...
	}
    }
  else
    container = dictionary;

  if (container->type == SOGoLDAPArray)
    {
      free (atom->key);
      atom->key = NULL;
    }
  _appendAtomToContainer (atom, container);
}

static _SOGoLDAPValue *
_readLDAPDictionaryWithHandle(const char *dn, LDAP *ldapHandle)
{
  struct timeval timeout;
  int rc;
  _SOGoLDAPValue *atom, *dictionary;
  LDAPMessage *messages, *message;
  BerElement *element;
  BerValue **values, **value;
  const char *attribute;

  dictionary = _createContainer (SOGoLDAPDictionary);

  timeout.tv_sec = 100;
  timeout.tv_usec = 0;
      
  rc = ldap_search_ext_s (ldapHandle, dn, LDAP_SCOPE_BASE, "(objectClass=*)",
			  NULL, 0, NULL, NULL, &timeout, 0, &messages);
  fprintf (stderr, "code: %d, %s\n", rc, ldap_err2string (rc));
  if (rc == LDAP_SUCCESS)
    {
      message = ldap_first_entry (ldapHandle, messages);
      if (message)
	{
	  attribute = ldap_first_attribute (ldapHandle, message, &element);
	  while (attribute)
	    {
	      values = ldap_get_values_len (ldapHandle, message, attribute);
	      value = values;
	      while (*value)
		{
		  if (strncmp ((*value)->bv_val, "dict-dn:", 8) == 0)
		    atom
		      = _readLDAPDictionaryWithHandle (((*value)->bv_val + 8),
						       ldapHandle);
		  else
		    atom = _createAtom (SOGoLDAPAtom,
					strdup ((*value)->bv_val));
		  atom->key = strdup (attribute);
		  _appendAtomToDictionary (atom, dictionary);
		  value++;
		}
	      ldap_value_free_len (values);
	      attribute = ldap_next_attribute (ldapHandle, message, element);
	    }
	}
      ldap_msgfree (message);
    }

  return dictionary;
}

static NSString *_convertLDAPAtomToNSString (_SOGoLDAPValue *atom);
static NSArray *_convertLDAPAtomToNSArray (_SOGoLDAPValue *atom);
static NSDictionary *_convertLDAPAtomToNSDictionary (_SOGoLDAPValue *atom);

static id
_convertLDAPAtomToNSObject (_SOGoLDAPValue *atom)
{
  id ldapObject;

  if (atom->type == SOGoLDAPAtom)
    ldapObject = _convertLDAPAtomToNSString (atom);
  else if (atom->type == SOGoLDAPArray)
    ldapObject = _convertLDAPAtomToNSArray (atom);
  else
    ldapObject = _convertLDAPAtomToNSDictionary (atom);

  return ldapObject;
}

static NSString *
_convertLDAPAtomToNSString (_SOGoLDAPValue *atom)
{
  NSString *ldapObject;

  ldapObject = [[NSString alloc]
		 initWithBytes: atom->value
		 length: strlen (atom->value)
		 encoding: NSUTF8StringEncoding];
  [ldapObject autorelease];

  return ldapObject;
}

static NSArray *
_convertLDAPAtomToNSArray (_SOGoLDAPValue *atom)
{
  _SOGoLDAPValue **currentSubAtom;
  NSMutableArray *ldapObject;

  ldapObject = [NSMutableArray array];

  currentSubAtom = atom->value;
  while (*currentSubAtom)
    {
      [ldapObject addObject: _convertLDAPAtomToNSObject (*currentSubAtom)];
      currentSubAtom++;
    }

  return ldapObject;
}

static NSDictionary *
_convertLDAPAtomToNSDictionary (_SOGoLDAPValue *atom)
{
  _SOGoLDAPValue **currentSubAtom;
  NSMutableDictionary *ldapObject;
  NSString *atomKey;

  ldapObject = [NSMutableDictionary dictionary];

  currentSubAtom = atom->value;
  while (*currentSubAtom)
    {
      atomKey = [[NSString alloc]
		  initWithBytes: (*currentSubAtom)->key
		  length: strlen ((*currentSubAtom)->key)
		  encoding: NSUTF8StringEncoding];
      [atomKey autorelease];
      [ldapObject setObject: _convertLDAPAtomToNSObject (*currentSubAtom)
		  forKey: atomKey];
      currentSubAtom++;
    }

  return ldapObject;
}

// dn = "cn=admin,dc=inverse,dc=ca";
// password = "qwerty";
// uri = "ldap://127.0.0.1";
// configDN = @"cn=sogo-config,dc=inverse,dc=ca";

static _SOGoLDAPValue *
_initLDAPDefaults ()
{
  const char *dn, *password, *uri, *configDN;
  LDAP *ldapHandle;
  int rc, opt;
  _SOGoLDAPValue *dictionary;

  ldap_initialize (&ldapHandle, uri);

  opt = LDAP_VERSION3;
  rc = ldap_set_option (ldapHandle, LDAP_OPT_PROTOCOL_VERSION, &opt);
  rc = ldap_set_option (ldapHandle, LDAP_OPT_REFERRALS, LDAP_OPT_OFF);
  // rc = ldap_sasl_bind_s (ldapHandle, dn, LDAP_SASL_NULL, password, NULL, NULL, &none);
  rc = ldap_simple_bind_s (ldapHandle, dn, password);
  if (rc == LDAP_SUCCESS)
    dictionary
      = _readLDAPDictionaryWithHandle (configDN, ldapHandle);
  else
    dictionary = _createContainer (SOGoLDAPDictionary);

  return dictionary;
}

- (id) objectForKey: (NSString *) key
{
  static _SOGoLDAPValue *SOGoLDAPDefaults = NULL;
  _SOGoLDAPValue **atom;
  id ldapObject;

  if (!SOGoLDAPDefaults)
    SOGoLDAPDefaults = _initLDAPDefaults ();

  atom = _findAtomInDictionary ([key UTF8String], SOGoLDAPDefaults);
  if (atom)
    ldapObject = _convertLDAPAtomToNSObject (*atom);
  else
    ldapObject = nil;

  if (!ldapObject)
    ldapObject = [super objectForKey: key];

  return ldapObject;
}

@end
