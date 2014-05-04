//
//  kingpinTests.m
//  kingpinTests
//
//  Created by Stanislaw Pankevich on 08/03/14.
//
//

#import "TestHelpers.h"

#import "KPGeometry.h"


@interface KPGeometryTests : XCTestCase
@end


@implementation KPGeometryTests

- (void)test_MKMapPointGetCoordinateForAxis {
    MKMapPoint mapPoint = MKMapPointMake(randomWithinRange(0, MKMapRectWorld.size.width), randomWithinRange(0, MKMapRectWorld.size.height));

    XCTAssertTrue(MKMapPointGetCoordinateForAxis(&mapPoint, 0) == mapPoint.x);
    XCTAssertTrue(MKMapPointGetCoordinateForAxis(&mapPoint, 1) == mapPoint.y);
}

@end
