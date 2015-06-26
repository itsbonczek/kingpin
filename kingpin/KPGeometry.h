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

#import <stddef.h>

#import <MapKit/MKGeometry.h>

static inline MKMapRect MKMapRectNormalizeToCellSize(MKMapRect mapRect, MKMapSize cellSize) {
    MKMapRect normalizedRect = mapRect;

    normalizedRect.origin.x -= ceil(fmod(normalizedRect.origin.x, cellSize.width));
    normalizedRect.origin.y -= ceil(fmod(normalizedRect.origin.y, cellSize.height));

    normalizedRect.size.width  += ceil((cellSize.width  - fmod(normalizedRect.size.width, cellSize.width)));
    normalizedRect.size.height += ceil((cellSize.height - fmod(normalizedRect.size.height, cellSize.height)));

    // Guard validation
    NSCAssert(((uint32_t)normalizedRect.size.width  % (uint32_t)cellSize.width)  == 0, nil);
    NSCAssert(((uint32_t)normalizedRect.size.height % (uint32_t)cellSize.height) == 0, nil);

    return normalizedRect;
}

static const size_t MKMapPointXOffset = offsetof(MKMapPoint, x);
static const size_t MKMapPointYOffset = offsetof(MKMapPoint, y);
static const size_t MKMapPointOffsets[] = { MKMapPointXOffset, MKMapPointYOffset };

// 64-Bit Transition Guide for Cocoa Touch - Do Not Cast Pointers to Integers
// (https://developer.apple.com/Library/ios/documentation/General/Conceptual/CocoaTouch64BitGuide/ConvertingYourAppto64-Bit/ConvertingYourAppto64-Bit.html
static inline double MKMapPointGetCoordinateForAxis(MKMapPoint *point, int axis) {
    return *(double *)((uintptr_t)point + MKMapPointOffsets[axis]);
}
