//
// Copyright 2012 Bryan Bonczek
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "NSArray+KP.h"


@implementation NSArray (KP)

- (NSArray *)kp_map:(id (^)(id))block {
    __block NSMutableArray *array = [NSMutableArray array];
    
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [array addObject:block(obj)];
    }];
    
    return array;
}

- (NSArray *)kp_filter:(BOOL (^)(id))block {
    __block NSMutableArray *array = [NSMutableArray array];
    
    [self enumerateObjectsWithOptions:0 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if(block(obj)) {
            [array addObject:obj];
        }
    }];

    return array;
}

@end
