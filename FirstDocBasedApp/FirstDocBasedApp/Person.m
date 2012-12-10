#import "Person.h"

@implementation Person

-(id)init {
    if (self = [super init]) {
        _name = @"Unnamed Person";
        _raise = 0.1;
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        _name = [aDecoder decodeObjectForKey:@"name"];
        _raise = [aDecoder decodeFloatForKey:@"raise"];
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_name forKey:@"name"];
    [aCoder encodeFloat:_raise forKey:@"raise"];
}

-(BOOL)hasEqualNameTo:(Person *)other {
    return [_name isEqualToString:other.name];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"%@ (%.2f%%)", _name, _raise * 100];
}

-(id)copyWithZone:(NSZone *)zone {
    Person *copy = [[Person alloc] init];
    copy.name = [_name copy];
    copy.raise = _raise;
    return copy;
}

@end
