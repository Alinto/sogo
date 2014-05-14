#include "SOGoCacheGCSObject+MAPIStore.h"

@implementation SOGoCacheGCSObject (MAPIStore)

- (Class) mapistoreMessageClass
{
  NSString *className, *mapiMsgClass;

  switch (objectType)
    {
    case MAPIMessageCacheObject:
      mapiMsgClass = [properties
                       objectForKey: MAPIPropertyKey (PidTagMessageClass)];
      if (mapiMsgClass)
        {
          if ([mapiMsgClass isEqualToString: @"IPM.StickyNote"])
            className = @"MAPIStoreNotesMessage";
          else
            className = @"MAPIStoreDBMessage";
          //[self logWithFormat: @"PidTagMessageClass = '%@', returning '%@'",
          //      mapiMsgClass, className];
        }
      else
        {
          //[self warnWithFormat: @"PidTagMessageClass is not set, falling back"
          //      @" to 'MAPIStoreDBMessage'"];
          className = @"MAPIStoreDBMessage";
        }
      break;
    case MAPIFAICacheObject:
      className = @"MAPIStoreFAIMessage";
      break;
    default:
      [NSException raise: @"MAPIStoreIOException"
                  format: @"message class should not be queried for objects"
                   @" of type '%d'", objectType];
    }

  return NSClassFromString (className);
}

@end
