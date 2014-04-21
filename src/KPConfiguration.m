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

#import "KPConfiguration.h"

@implementation KPConfiguration

- (id)init {
    self = [super init];

    if (self == nil) return nil;

    self.gridSize = (CGSize){60.f, 60.f};
    self.annotationSize = (CGSize){60.f, 60.f};
    self.annotationCenterOffset = (CGPoint){30.f, 30.f};
    self.animationDuration = 0.5f;
    self.clusteringEnabled = YES;

    return self;
}

@end
