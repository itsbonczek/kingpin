//
//  TestAnnotation.h
//  BBAnnotationTree2
//
//  Created by Bryan Bonczek on 6/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TestAnnotation : NSObject <MKAnnotation>

@property (nonatomic, assign) NSInteger level;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

@end
