/* MAPIStoreTable.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#import <Foundation/NSException.h>

#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOQualifier.h>

#import "EOBitmaskQualifier.h"
#import "MAPIStoreActiveTables.h"
#import "MAPIStoreObject.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreContext.h"
#import "MAPIStoreObject.h"

#import "MAPIStoreTable.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <libmapiproxy.h>

@interface MAPIStoreTable (Private)

- (MAPIRestrictionState) evaluateRestriction: (const struct mapi_SRestriction *) res
			       intoQualifier: (EOQualifier **) qualifier;
@end

static Class NSDataK, NSStringK;

// static NSString *
// MAPIStringForRestrictionState (MAPIRestrictionState state)
// {
//   NSString *stateStr;

//   if (state == MAPIRestrictionStateAlwaysTrue)
//     stateStr = @"always true";
//   else if (state == MAPIRestrictionStateAlwaysFalse)
//     stateStr = @"always false";
//   else
//     stateStr = @"needs eval";

//   return stateStr;
// }

// static NSString *
// MAPIStringForRestriction (const struct mapi_SRestriction *resPtr);

// static NSString *
// _MAPIIndentString(int indent)
// {
//   NSString *spaces;
//   char *buffer;

//   if (indent > 0)
//     {
//       buffer = malloc (indent + 1);
//       memset (buffer, 32, indent);
//       *(buffer+indent) = 0;
//       spaces = [NSString stringWithFormat: @"%s", buffer];
//       free (buffer);
//     }
//   else
//     spaces = @"";

//   return spaces;
// }

// static NSString *
// MAPIStringForAndRestriction (const struct mapi_SAndRestriction *resAnd)
// {
//   NSMutableArray *restrictions;
//   uint16_t count;

//   restrictions = [NSMutableArray arrayWithCapacity: 8];
//   for (count = 0; count < resAnd->cRes; count++)
//     [restrictions addObject: MAPIStringForRestriction ((struct mapi_SRestriction *) resAnd->res + count)];

//   return [NSString stringWithFormat: @"(%@)", [restrictions componentsJoinedByString: @" && "]];
// }

// static NSString *
// MAPIStringForOrRestriction (const struct mapi_SOrRestriction *resOr)
// {
//   NSMutableArray *restrictions;
//   uint16_t count;

//   restrictions = [NSMutableArray arrayWithCapacity: 8];
//   for (count = 0; count < resOr->cRes; count++)
//     [restrictions addObject: MAPIStringForRestriction ((struct mapi_SRestriction *) resOr->res + count)];

//   return [NSString stringWithFormat: @"(%@)", [restrictions componentsJoinedByString: @" || "]];
// }

// static NSString *
// MAPIStringForNotRestriction (const struct mapi_SNotRestriction *resNot)
// {
//   return [NSString stringWithFormat: @"!(%@)",
// 		   MAPIStringForRestriction ((struct mapi_SRestriction *) &resNot->res)];
// }

// static NSString *
// MAPIStringForContentRestriction (const struct mapi_SContentRestriction *resContent)
// {
//   NSString *eqMatch, *caseMatch;
//   id value;
//   const char *propName;

//   switch (resContent->fuzzy & 0xf)
//     {
//     case 0: eqMatch = @"eq"; break;
//     case 1: eqMatch = @"substring"; break;
//     case 2: eqMatch = @"prefix"; break;
//     default: eqMatch = @"[unknown]";
//     }

//   switch (((resContent->fuzzy) >> 16) & 0xf)
//     {
//     case 0: caseMatch = @"fl"; break;
//     case 1: caseMatch = @"nc"; break;
//     case 2: caseMatch = @"ns"; break;
//     case 4: caseMatch = @"lo"; break;
//     default: caseMatch = @"[unknown]";
//     }

//   propName = get_proptag_name (resContent->ulPropTag);
//   if (!propName)
//     propName = "<unknown>";

//   value = NSObjectFromMAPISPropValue (&resContent->lpProp);

//   return [NSString stringWithFormat: @"%s(0x%.8x) %@,%@ %@",
// 		   propName, resContent->ulPropTag, eqMatch, caseMatch, value];
// }

// static NSString *
// MAPIStringForExistRestriction (const struct mapi_SExistRestriction *resExist)
// {
//   const char *propName;

//   propName = get_proptag_name (resExist->ulPropTag);
//   if (!propName)
//     propName = "<unknown>";

//   return [NSString stringWithFormat: @"%s(0x%.8x) IS NOT NULL", propName, resExist->ulPropTag];
// }

// static NSString *
// MAPIStringForPropertyRestriction (const struct mapi_SPropertyRestriction *resProperty)
// {
//   static NSString *operators[] = { @"<", @"<=", @">", @">=", @"==", @"!=",
// 				   @"=~" };
//   NSString *operator;
//   id value;
//   const char *propName;

//   propName = get_proptag_name (resProperty->ulPropTag);
//   if (!propName)
//     propName = "<unknown>";

//   if (resProperty->relop >= 0 && resProperty->relop < 7)
//     operator = operators[resProperty->relop];
//   else
//     operator = [NSString stringWithFormat: @"<invalid op %d>", resProperty->relop];
//   value = NSObjectFromMAPISPropValue (&resProperty->lpProp);

//   return [NSString stringWithFormat: @"%s(0x%.8x) %@ %@",
// 		   propName, resProperty->ulPropTag, operator, value];
// }

// static NSString *
// MAPIStringForBitmaskRestriction (const struct mapi_SBitmaskRestriction *resBitmask)
// {
//   NSString *format;
//   const char *propName;

//   propName = get_proptag_name (resBitmask->ulPropTag);
//   if (!propName)
//     propName = "<unknown>";

//   if (resBitmask->relMBR == 0)
//     format = @"((%s(0x%.8x) & 0x%.8x) == 0)";
//   else
//     format = @"((%s(0x%.8x) & 0x%.8x) != 0)";

//   return [NSString stringWithFormat: format,
// 		   propName, resBitmask->ulPropTag, resBitmask->ulMask];
// }

// static NSString *
// MAPIStringForRestriction (const struct mapi_SRestriction *resPtr)
// {
//   NSString *restrictionStr;

//   if (resPtr)
//     {
//       switch (resPtr->rt)
// 	{
// 	  // RES_CONTENT=(int)(0x3),
// 	  // RES_BITMASK=(int)(0x6),
// 	  // RES_EXIST=(int)(0x8),

// 	case 0: restrictionStr = MAPIStringForAndRestriction(&resPtr->res.resAnd); break;
// 	case 1: restrictionStr = MAPIStringForOrRestriction(&resPtr->res.resOr); break;
// 	case 2: restrictionStr = MAPIStringForNotRestriction(&resPtr->res.resNot); break;
// 	case 3: restrictionStr = MAPIStringForContentRestriction(&resPtr->res.resContent); break;
// 	case 4: restrictionStr = MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
// 	case 6: restrictionStr = MAPIStringForBitmaskRestriction(&resPtr->res.resBitmask); break;
// 	case 8: restrictionStr = MAPIStringForExistRestriction(&resPtr->res.resExist); break;
// 	  // case 5: MAPIStringForComparePropsRestriction(&resPtr->res.resCompareProps); break;
// 	  // case 7: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
// 	  // case 9: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
// 	  // case 10: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
// 	default:
// 	  restrictionStr
// 	    = [NSString stringWithFormat: @"[unhandled restriction type: %d]",
// 			resPtr->rt];
// 	}
//     }
//   else
//     restrictionStr = @"[unrestricted]";

//   return restrictionStr;
// }

@implementation MAPIStoreTable

+ (void) initialize
{
  NSDataK = [NSData class];
  NSStringK = [NSString class];
}

+ (id) tableForContainer: (MAPIStoreObject *) newContainer
{
  MAPIStoreTable *newTable;

  newTable = [[self alloc] initForContainer: newContainer];
  [newTable autorelease];

  return newTable;
}

+ (Class) childObjectClass
{
  [self subclassResponsibility: _cmd];

  return Nil;
}

- (id) init
{
  if ((self = [super init]))
    {
      [self logWithFormat: @"-init"];
      tableType = MAPISTORE_MESSAGE_TABLE;
      handleId = -1;

      container = nil;

      childKeys = nil;
      restrictedChildKeys = nil;

      currentRow = (uint32_t) -1;
      currentChild = nil;

      restriction = nil;
      restrictionState = MAPIRestrictionStateAlwaysTrue;
      sortOrderings = nil;

      columns = NULL;
      columnsCount = 0;
    }

  return self;
}

- (id) initForContainer: (MAPIStoreObject *) newContainer
{
  if ((self = [self init]))
    {
      container = newContainer;
    }

  return self;
}

- (id) retain
{
  [self logWithFormat: @"-retain"];
  return [super retain];
}

- (void) release
{
  [self logWithFormat: @"-release"];
  [super release];
}

- (void) dealloc
{
  [self logWithFormat: @"-dealloc"];
  if (columns)
    NSZoneFree (NULL, columns);
  [currentChild release];
  [childKeys release];
  [restrictedChildKeys release];
  [sortOrderings release];
  [restriction release];
  [super dealloc];
}

- (id) container
{
  return container;
}

- (enum mapistore_table_type) tableType
{
  return tableType;
}

- (void) setHandleId: (uint32_t) newHandleId
{
  handleId = newHandleId;
  if (newHandleId)
    [[MAPIStoreActiveTables activeTables] registerTable: self];
}

- (void) destroyHandle: (uint32_t) tableHandleId
{
  if (tableHandleId && (handleId == tableHandleId))
    [[MAPIStoreActiveTables activeTables] unregisterTable: self];
}

- (void) cleanupCaches
{
  [restrictedChildKeys release];
  restrictedChildKeys = nil;
  [childKeys release];
  childKeys = nil;
  [currentChild release];
  currentChild = nil;
  currentRow = (uint32_t) -1;
}

- (int) getAvailableProperties: (struct SPropTagArray **) propertiesP
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[isa childObjectClass] getAvailableProperties: propertiesP
                                               inMemCtx: memCtx];
}

- (void) setRestrictions: (const struct mapi_SRestriction *) res
{
  EOQualifier *oldRestriction;

  // [self logWithFormat: @"set restriction to (table type: %d): %@",
  // 	type, MAPIStringForRestriction (res)];

  oldRestriction = restriction;
  [restriction autorelease];
  if (res)
    restrictionState = [self evaluateRestriction: res
				   intoQualifier: &restriction];
  else
    restrictionState = MAPIRestrictionStateAlwaysTrue;
  
  if (restrictionState == MAPIRestrictionStateNeedsEval)
    [restriction retain];
  else
    restriction = nil;
  
  // FIXME: we should not flush the caches if the restrictions matches
  [self cleanupCaches];
  
  if (restriction)
    [self logWithFormat: @"restriction set to EOQualifier: %@",
	  restriction];
  else if (oldRestriction)
    [self logWithFormat: @"restriction unset (was %@)", oldRestriction];
}

- (MAPIRestrictionState) evaluateNotRestriction: (struct mapi_SNotRestriction *) res
				  intoQualifier: (EOQualifier **) qualifierPtr
{
  MAPIRestrictionState state, subState;
  EONotQualifier *qualifier;
  EOQualifier *subQualifier;

  subState = [self evaluateRestriction: (struct mapi_SRestriction *)&res->res
			 intoQualifier: &subQualifier];
  if (subState == MAPIRestrictionStateAlwaysTrue)
    state = MAPIRestrictionStateAlwaysFalse;
  else if (subState == MAPIRestrictionStateAlwaysFalse)
    state = MAPIRestrictionStateAlwaysTrue;
  else
    {
      state = MAPIRestrictionStateNeedsEval;
      qualifier = [[EONotQualifier alloc] initWithQualifier: subQualifier];
      [qualifier autorelease];
      *qualifierPtr = qualifier;
    }

  return state;
}

- (MAPIRestrictionState) evaluateAndRestriction: (struct mapi_SAndRestriction *) res
				  intoQualifier: (EOQualifier **) qualifierPtr
{
  MAPIRestrictionState state, subState;
  EOAndQualifier *qualifier;
  EOQualifier *subQualifier;
  NSMutableArray *subQualifiers;
  uint16_t count;

  state = MAPIRestrictionStateNeedsEval;

  subQualifiers = [NSMutableArray arrayWithCapacity: 8];
  for (count = 0;
       state == MAPIRestrictionStateNeedsEval && count < res->cRes;
       count++)
    {
      subState = [self evaluateRestriction: (struct mapi_SRestriction *) res->res + count
			     intoQualifier: &subQualifier];
      if (subState == MAPIRestrictionStateNeedsEval)
	[subQualifiers addObject: subQualifier];
      else if (subState == MAPIRestrictionStateAlwaysFalse)
	state = MAPIRestrictionStateAlwaysFalse;
    }

  if (state == MAPIRestrictionStateNeedsEval)
    {
      if ([subQualifiers count] == 0)
	state = MAPIRestrictionStateAlwaysTrue;
      else
	{
	  qualifier = [[EOAndQualifier alloc]
			initWithQualifierArray: subQualifiers];
	  [qualifier autorelease];
	  *qualifierPtr = qualifier;
	}
    }

  return state;
}

- (MAPIRestrictionState) evaluateOrRestriction: (struct mapi_SOrRestriction *) res
				 intoQualifier: (EOQualifier **) qualifierPtr
{
  MAPIRestrictionState state, subState;
  EOOrQualifier *qualifier;
  EOQualifier *subQualifier;
  NSMutableArray *subQualifiers;
  uint16_t count, falseCount;

  state = MAPIRestrictionStateNeedsEval;

  falseCount = 0;
  subQualifiers = [NSMutableArray arrayWithCapacity: 8];
  for (count = 0;
       state == MAPIRestrictionStateNeedsEval && count < res->cRes;
       count++)
    {
      subState = [self evaluateRestriction: (struct mapi_SRestriction *) res->res + count
			     intoQualifier: &subQualifier];
      if (subState == MAPIRestrictionStateNeedsEval)
	[subQualifiers addObject: subQualifier];
      else if (subState == MAPIRestrictionStateAlwaysTrue)
	state = MAPIRestrictionStateAlwaysTrue;
      else
	falseCount++;
    }

  if (falseCount == res->cRes)
    state = MAPIRestrictionStateAlwaysFalse;
  else if ([subQualifiers count] == 0)
    state = MAPIRestrictionStateAlwaysTrue;

  if (state == MAPIRestrictionStateNeedsEval)
    {
      qualifier = [[EOOrQualifier alloc]
		    initWithQualifierArray: subQualifiers];
      [qualifier autorelease];
      *qualifierPtr = qualifier;
    }

  return state;
}

- (void) warnUnhandledProperty: (enum MAPITAGS) property
                    inFunction: (const char *) function
{
  const char *propName;

  propName = get_proptag_name (property);
  if (!propName)
    propName = "<unknown>";
  [self warnWithFormat:
	  @"property %s (%.8x) has no matching field name (%@) in '%s'",
	propName, property, self, function];
}

- (MAPIRestrictionState) evaluateContentRestriction: (struct mapi_SContentRestriction *) res
				      intoQualifier: (EOQualifier **) qualifier
{
  NSString *property;
  // SEL operator;
  id value;
  MAPIRestrictionState rc;

  property = [self backendIdentifierForProperty: res->ulPropTag];
  if (property)
    {  
      value = NSObjectFromMAPISPropValue (&res->lpProp);
      if ([value isKindOfClass: NSDataK])
	{
	  value = [[NSString alloc] initWithData: value
					encoding: NSUTF8StringEncoding];
	  [value autorelease];
	}
      else if (![value isKindOfClass: NSStringK])
	[NSException raise: @"MAPIStoreTypeConversionException"
		    format: @"unhandled content restriction for class '%@'",
		     NSStringFromClass ([value class])];

      // switch (res->fuzzy & 0xf)
      //   {
      //   case 0:
      //     operator = EOQualifierOperatorEqual;
      //     break;
      //   case 1:
      //     operator = EOQualifierOperatorLike;
      //     value = [NSString stringWithFormat: @"%%%@%%", value];
      //     break;
      //   case 2:
      //     operator = EOQualifierOperatorEqual;
      //     value = [NSString stringWithFormat: @"%@%%", value];
      //     break;
      //   default: [NSException raise: @"MAPIStoreInvalidOperatorException"
      //   		     format: @"fuzzy operator value '%.4x' is invalid",
      //   		      res->fuzzy];
      //   }
      
      *qualifier = [[EOKeyValueQualifier alloc] initWithKey: property
					   operatorSelector: EOQualifierOperatorCaseInsensitiveLike
						      value: value];
      [*qualifier autorelease];

      [self logWithFormat: @"%s: resulting qualifier: %@",
	    __PRETTY_FUNCTION__, *qualifier];
      
      rc =  MAPIRestrictionStateNeedsEval;
    }
  else
    {
      [self warnUnhandledProperty: res->ulPropTag
                       inFunction: __FUNCTION__];
      
      rc = MAPIRestrictionStateAlwaysFalse;
    }

  return rc;
}

- (SEL) operatorFromRestrictionOperator: (uint32_t) resOp
{
  static SEL operators[] = { EOQualifierOperatorLessThan,
			     EOQualifierOperatorLessThanOrEqualTo,
			     EOQualifierOperatorGreaterThan,
			     EOQualifierOperatorGreaterThanOrEqualTo,
			     EOQualifierOperatorEqual,
			     EOQualifierOperatorNotEqual,
			     EOQualifierOperatorContains };
  SEL operator;

  if (resOp < 7)
    operator = operators[resOp];
  else
    {
      operator = NULL;
      [NSException raise: @"MAPIStoreRestrictionException"
                  format: @"unhandled operator type number %d", resOp];
    }

  return operator;
}

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  SEL operator;
  id value;
  NSString *property;
  MAPIRestrictionState rc;

  property = [self backendIdentifierForProperty: res->ulPropTag];
  if (property)
    {
      operator = [self operatorFromRestrictionOperator: res->relop];
      value = NSObjectFromMAPISPropValue (&res->lpProp);
      *qualifier = [[EOKeyValueQualifier alloc] initWithKey: property
					   operatorSelector: operator
						      value: value];
      [*qualifier autorelease];
      
      rc = MAPIRestrictionStateNeedsEval;
    }
  else
    {
      [self warnUnhandledProperty: res->ulPropTag
                       inFunction: __FUNCTION__];
      rc = MAPIRestrictionStateAlwaysFalse;
    }

  return rc;
}

- (MAPIRestrictionState) evaluateBitmaskRestriction: (struct mapi_SBitmaskRestriction *) res
				      intoQualifier: (EOQualifier **) qualifier
{
  NSString *property;
  MAPIRestrictionState rc;

  property = [self backendIdentifierForProperty: res->ulPropTag];
  if (property)
    {
      *qualifier = [[EOBitmaskQualifier alloc] initWithKey: property
						      mask: res->ulMask
						    isZero: (res->relMBR == BMR_EQZ)];
      [*qualifier autorelease];

      rc = MAPIRestrictionStateNeedsEval;
    }
  else
    {
      [self warnUnhandledProperty: res->ulPropTag
                       inFunction: __FUNCTION__];
      rc = MAPIRestrictionStateAlwaysFalse;
    }

  return rc;
}

- (MAPIRestrictionState) evaluateExistRestriction: (struct mapi_SExistRestriction *) res
				    intoQualifier: (EOQualifier **) qualifier
{
  NSString *property;
  MAPIRestrictionState rc;

  property = [self backendIdentifierForProperty: res->ulPropTag];
  if (property)
    {
      *qualifier = [[EOKeyValueQualifier alloc] initWithKey: property
					   operatorSelector: EOQualifierOperatorNotEqual
						      value: nil];
      [*qualifier autorelease];
      
      rc = MAPIRestrictionStateNeedsEval;
    }
  else
    {
      [self warnUnhandledProperty: res->ulPropTag
                       inFunction: __FUNCTION__];
      rc = MAPIRestrictionStateAlwaysFalse;
    }

  return rc;
}

- (MAPIRestrictionState) evaluateRestriction: (struct mapi_SRestriction *) res
			       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState state;

  switch (res->rt)
    {
      /* basic operators */
    case RES_AND: state = [self evaluateAndRestriction: &res->res.resAnd
                                         intoQualifier: qualifier];
      break;
    case RES_OR: state = [self evaluateOrRestriction: &res->res.resOr
                                       intoQualifier: qualifier];
      break;
    case RES_NOT: state = [self evaluateNotRestriction: &res->res.resNot
                                         intoQualifier: qualifier];
      break;

      /* content restrictions */
    case RES_CONTENT: state = [self evaluateContentRestriction: &res->res.resContent
                                                 intoQualifier: qualifier];
      break;
    case RES_PROPERTY: state = [self evaluatePropertyRestriction: &res->res.resProperty
                                                   intoQualifier: qualifier];
      break;
    case RES_BITMASK: state = [self evaluateBitmaskRestriction: &res->res.resBitmask
                                                 intoQualifier: qualifier];
      break;

    case RES_SIZE: state = MAPIRestrictionStateAlwaysTrue; /* let's cheat a little */
      break;
    case RES_EXIST: state = [self evaluateExistRestriction: &res->res.resExist
                                             intoQualifier: qualifier];
      break;

    case RES_COMMENT:
      if (res->res.resComment.RestrictionPresent)
        state = [self evaluateRestriction: (struct mapi_SRestriction *) res->res.resComment.Restriction.res
                            intoQualifier: qualifier];
      else
        state = MAPIRestrictionStateAlwaysTrue;
      break;

    // case 5: MAPIStringForComparePropsRestriction(&resPtr->res.resCompareProps); break;
    // case 7: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
    // case 9: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
    // case 10: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
    default:
      [NSException raise: @"MAPIStoreRestrictionException"
                   format: @"unhandled restriction type: %.2x", res->rt];
      state = MAPIRestrictionStateAlwaysTrue;
    }

  // [self logRestriction: res withState: state];

  return state;
}

/* proof of concept */
- (int) setColumns: (enum MAPITAGS *) newColumns
         withCount: (uint16_t) newColumnsCount
{
  NSUInteger count;

  if (columns)
    NSZoneFree (NULL, columns);
  columns = NSZoneMalloc (NULL, newColumnsCount * sizeof (enum MAPITAGS));
  for (count = 0; count < newColumnsCount; count++)
    columns[count] = newColumns[count];
  columnsCount = newColumnsCount;

  return MAPISTORE_SUCCESS;
}

- (id) childAtRowID: (uint32_t) rowId
       forQueryType: (enum mapistore_query_type) queryType
{
  id child;
  NSArray *children, *restrictedChildren;
  NSString *childKey;

  if (rowId == currentRow)
    child = currentChild;
  else
    {
      [currentChild release];
      child = nil;

      if (queryType == MAPISTORE_PREFILTERED_QUERY)
        {
          children = [self restrictedChildKeys];
          restrictedChildren = nil;
        }
      else
        {
          children = [self childKeys];
          restrictedChildren = [self restrictedChildKeys];
        }

      if ([children count] > rowId)
        {
          childKey = [children objectAtIndex: rowId];
          
          if (queryType == MAPISTORE_PREFILTERED_QUERY
              || [restrictedChildren containsObject: childKey])
            child = [self lookupChild: childKey];
        }

      currentChild = child;
      [currentChild retain];

      if (child)
        currentRow = rowId;
      else
        currentRow = (uint32_t) -1;
    }

  return child;
}

- (NSArray *) childKeys
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSArray *) restrictedChildKeys
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (id) lookupChild: (NSString *) childKey
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (int) getRow: (struct mapistore_property_data **) dataP
     withRowID: (uint32_t) rowId
  andQueryType: (enum mapistore_query_type) queryType
      inMemCtx: (TALLOC_CTX *) memCtx
{
  NSUInteger count;
  MAPIStoreObject *child;
  struct mapistore_property_data *rowData;
  int rc;

  child = [self childAtRowID: rowId
                forQueryType: queryType];
  if (child)
    {
      rowData = talloc_array(memCtx, struct mapistore_property_data, columnsCount);
      for (count = 0; count < columnsCount; count++)
        rowData[count].error = [child getProperty: &rowData[count].data
                                          withTag: columns[count]
                                         inMemCtx: memCtx];
      *dataP = rowData;
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getRowCount: (uint32_t *) countP
      withQueryType: (enum mapistore_query_type) queryType
{
  NSArray *children;

  if (queryType == MAPISTORE_PREFILTERED_QUERY)
    children = [self restrictedChildKeys];
  else
    children = [self childKeys];

  *countP = [children count];

  return MAPISTORE_SUCCESS;
}

- (void) notifyChangesForChild: (MAPIStoreObject *) child
{
  NSUInteger currentChildRow, newChildRow;
  NSArray *list;
  NSString *childName;
  struct mapistore_table_notification_parameters notif_parameters;
  struct mapistore_context *mstoreCtx;

  mstoreCtx = [[container context] connectionInfo]->mstore_ctx;

  notif_parameters.table_type = tableType;
  notif_parameters.handle = handleId;
  notif_parameters.folder_id = [container objectId];
  notif_parameters.object_id = [child objectId];
  notif_parameters.instance_id = 0; /* TODO: always 0 ? */

  childName = [child nameInContainer];
  list = [self restrictedChildKeys];
  currentChildRow = [list indexOfObject: childName];
  notif_parameters.row_id = currentChildRow;

  [self cleanupCaches];
  list = [self restrictedChildKeys];
  newChildRow = [list indexOfObject: childName];

  if (currentChildRow == NSNotFound)
    {
      if (newChildRow != NSNotFound)
        {
          notif_parameters.row_id = newChildRow;
          mapistore_push_notification (mstoreCtx,
                                       MAPISTORE_TABLE,
                                       MAPISTORE_OBJECT_CREATED,
                                       &notif_parameters);
        }
    }
  else
    {
      if (newChildRow == NSNotFound)
        mapistore_push_notification (mstoreCtx,
                                     MAPISTORE_TABLE,
                                     MAPISTORE_OBJECT_DELETED,
                                     &notif_parameters);
      else
        {
          /* the fact that the row order has changed has no impact here */
          notif_parameters.row_id = newChildRow;
          mapistore_push_notification (mstoreCtx,
                                       MAPISTORE_TABLE,
                                       MAPISTORE_OBJECT_MODIFIED,
                                       &notif_parameters);
        }
    }
}

/* subclasses */
- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (void) setSortOrder: (const struct SSortOrderSet *) set
{
  [self subclassResponsibility: _cmd];
}

@end
