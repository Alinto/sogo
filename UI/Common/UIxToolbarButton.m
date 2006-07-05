#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#import <SOGoUI/UIxComponent.h>

@interface UIxToolbarButton : UIxComponent
{
  NSString *buttonImage;
  NSString *buttonLabel;
  NSString *buttonLink;
  NSString *buttonTooltip;
}

- (void) setButtonImage: (NSString *) newButtonImage;
- (NSString *) buttonImage;

- (void) setButtonLabel: (NSString *) newButtonLabel;
- (NSString *) buttonLabel;

- (void) setButtonLink: (NSString *) newButtonLink;
- (NSString *) buttonLink;

- (void) setButtonTooltip: (NSString *) newButtonTooltip;
- (NSString *) buttonTooltip;

@end

@implementation UIxToolbarButton


- (id) init
{
  if ((self = [super init]))
    {
      buttonImage = nil;
      buttonLabel = nil;
      buttonLink = nil;
      buttonTooltip = nil;
    }

  return self;
}

- (void) dealloc
{
  if (buttonImage)
    [buttonImage release];
  if (buttonLabel)
    [buttonLabel release];
  if (buttonLink)
    [buttonLink release];
  if (buttonTooltip)
    [buttonTooltip release];
  [super dealloc];
}

- (void) setButtonLabel: (NSString *) newButtonLabel
{
  if (buttonLabel)
    [buttonLabel release];
  buttonLabel = newButtonLabel;
  if (buttonLabel)
    [buttonLabel retain];
}

- (NSString *) buttonLabel
{
  return buttonLabel;
}

- (void) setButtonImage: (NSString *) newButtonImage
{
  if (buttonImage)
    [buttonImage release];
  buttonImage = newButtonImage;
  if (buttonImage)
    [buttonImage retain];
}

- (NSString *) buttonImage
{
  return buttonImage;
}

- (void) setButtonLink: (NSString *) newButtonLink
{
  if (buttonLink)
    [buttonLink release];
  buttonLink = newButtonLink;
  if (buttonLink)
    [buttonLink retain];
}

- (NSString *) buttonLink
{
  return [self completeHrefForMethod: buttonLink];
}

- (void) setButtonTooltip: (NSString *) newButtonTooltip
{
  if (buttonTooltip)
    [buttonTooltip release];
  buttonTooltip = newButtonTooltip;
  if (buttonTooltip)
    [buttonTooltip retain];
}

- (NSString *) buttonTooltip
{
  return buttonTooltip;
}

@end
