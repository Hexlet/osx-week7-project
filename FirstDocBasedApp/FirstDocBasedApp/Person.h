#import <Foundation/Foundation.h>

@interface Person : NSObject<NSCoding, NSCopying>
@property NSString *name;
@property float raise;

-(BOOL)hasEqualNameTo:(Person *)other;
@end
