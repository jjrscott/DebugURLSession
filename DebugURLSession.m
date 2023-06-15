//
//  DebugURLSession.m
//
//  Created by John Scott on 01/03/2023.
//

/**
 The following code, when enabled, prints every -[NSURLSession dataTaskWithRequest:completionHandler:] call made.
 This includes any imported frameworks. Everything.
 
 WARNING. Do NOT enable this for the AppStore, it WILL  be rejected.
*/

#if ENABLE_URLSESSION_DEBUGGING

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

void Log(NSString *format, ...) NS_FORMAT_FUNCTION(1,2) NS_NO_TAIL_CALL;
void Log(NSString *format, ...) {
    va_list arguments;
    va_start (arguments, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:arguments];
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    [NSFileHandle.fileHandleWithStandardError writeData:data];
    va_end (arguments);
}

void SetSuperclass(Class _Nonnull cls, Class _Nonnull newSuper);
void SetSuperclass(Class _Nonnull cls, Class _Nonnull newSuper) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        class_setSuperclass(cls, newSuper);
#pragma clang diagnostic pop
}

@interface DebugURLSession : NSURLSession

@end

@implementation NSURLSession (DebugURLSession)

// Hijack the NSURLSession (and subclass) allocations to insert DebugURLSession into the
// inheritance chain.
+(instancetype)alloc {
    if (self != DebugURLSession.class && [self superclass] == NSURLSession.class) {
        Log(@"Setting supper class for %@\n", NSStringFromClass(self));
        SetSuperclass(self, DebugURLSession.class);
        return [NSClassFromString(NSStringFromClass(self)) alloc];
    } else {
        return [super alloc];
    }
}

@end

@implementation NSData (NSData_Conversion)

- (NSString *)hexEncodedString
{
    /* Returns hexadecimal string of NSData. Empty string if data is empty.   */
    
    NSMutableString *hexString = [NSMutableString stringWithCapacity: self.length * 2];
    
    [self enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
        for (int i = 0; i < byteRange.length; ++i)
        {
            [hexString appendFormat:@"%02x", ((unsigned char *)bytes)[i]];
        }
    }];
    
    return [NSString stringWithString:hexString];
}

@end

@implementation DebugURLSession

// Attempt to decode the data into somthing useful
-(NSString*)decodeObject:(id)object {
    if (object == nil) {
        return nil;
    }
    NSData* data = [NSJSONSerialization dataWithJSONObject:[self convertToJSOMPrimitives:object]
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys | NSJSONWritingWithoutEscapingSlashes
                                                     error:NULL];
    
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}

-(id)convertToJSOMPrimitives:(id)value {
    if ([value isKindOfClass:NSData.class]) {
        id object = [NSJSONSerialization JSONObjectWithData:value options:kNilOptions error:NULL];
        if (object != nil) {
            return object;
        }

        NSString *string = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
        
        if (string != nil) {
            return string;
        }
        
        return [value hexEncodedString];
    } else if ([value isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *result = [NSMutableDictionary new];
        [value enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            result[key] = [self convertToJSOMPrimitives:obj];
        }];
        return result;
        
    } else if ([value isKindOfClass:NSError.class]) {
        NSError *error = value;
        return @{
            @"0 domain" : error.domain,
            @"1 code" : @(error.code),
            @"2 localizedDescription" : error.localizedDescription,
            @"3 userInfo": [self convertToJSOMPrimitives:error.userInfo],
        };
    } else if ([value isKindOfClass:NSNull.class] || [value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class]) {
        return value;
    } else {
        return [value description];
    }
}

-(NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    
    id requestObject = @{
        @"0 url": request.URL ?: NSNull.null,
        @"1 headers": request.allHTTPHeaderFields ?: NSNull.null,
        @"2 body": request.HTTPBody ?: NSNull.null,
    };
    
    return [super dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        id responseObject = @{
            @"0 url": httpResponse.URL ?: NSNull.null,
            @"1 status": @(httpResponse.statusCode) ?: NSNull.null,
            @"2 headers": httpResponse.allHeaderFields ?: NSNull.null,
            @"3 body": data ?: NSNull.null,
            @"4 error": error ?: NSNull.null,
        };
        
        Log(@"dataTaskResponse: %@\n", [self decodeObject:@{@"request" : requestObject, @"response" : responseObject}]);
        completionHandler(data, response, error);
    }];
}

@end

#endif
