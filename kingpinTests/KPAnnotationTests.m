//
//  kingpinTests.m
//  kingpinTests
//
//  Created by Stanislaw Pankevich on 08/03/14.
//
//

#import "TestHelpers.h"

#import "KPAnnotation.h"
#import "TestAnnotation.h"


@interface KPAnnotationTests : XCTestCase
@end


@implementation KPAnnotationTests

- (void)testCalculateValuesForClusterAnnotationHavingOneAnnotation
{
    CLLocationCoordinate2D NYCoord = CLLocationCoordinate2DMake(randomWithinRange(-90, 90), randomWithinRange(-180, 180));

    TestAnnotation *a1 = [[TestAnnotation alloc] init];
    a1.coordinate = CLLocationCoordinate2DMake(NYCoord.latitude,
                                               NYCoord.longitude);

    KPAnnotation *annotation = [[KPAnnotation alloc] initWithAnnotations:@[ a1 ]];

    XCTAssertTrue(CLLocationCoordinates2DEqual(NYCoord, annotation.coordinate));
}

- (void)testCalculateValuesForClusterAnnotationHavingManyClusters {
    CLLocationCoordinate2D NYCoord = CLLocationCoordinate2DMake(40.77, -73.98);

    NSMutableArray *annotations = [NSMutableArray array];

    CLLocationCoordinate2D nycCoord = NYCoord;

    NSUInteger randomNumberOfAnnotations = 1 + arc4random_uniform(1000);

    for (int i = 0; i < randomNumberOfAnnotations; i++) {
        CLLocationDegrees latAdj = (CLLocationDegrees)((random() % 100) / 1000);
        CLLocationDegrees lngAdj = (CLLocationDegrees)((random() % 100) / 1000);

        TestAnnotation *a = [[TestAnnotation alloc] init];
        a.coordinate = CLLocationCoordinate2DMake(nycCoord.latitude + latAdj,
                                                   nycCoord.longitude + lngAdj);
        [annotations addObject:a];
    }

    KPAnnotation *annotation = [[KPAnnotation alloc] initWithAnnotations:annotations];

    NSUInteger annotationsCount = [annotations count];

    CLLocationDegrees totalLatitudeOfAllAnnotationsCoordinates = 0;
    CLLocationDegrees totalLongitudeOfAllAnnotationsCoordinates = 0;

    for (int i = 0; i < randomNumberOfAnnotations; i++) {
        CLLocationCoordinate2D annotationCoordinate = [annotations[i] coordinate];

        totalLatitudeOfAllAnnotationsCoordinates += annotationCoordinate.latitude;
        totalLongitudeOfAllAnnotationsCoordinates += annotationCoordinate.longitude;
    }

    CLLocationCoordinate2D annotationCentroidCoordinate = CLLocationCoordinate2DMake(totalLatitudeOfAllAnnotationsCoordinates / annotationsCount, totalLongitudeOfAllAnnotationsCoordinates / annotationsCount);

    XCTAssertTrue(CLLocationCoordinates2DEqual(annotation.coordinate, annotationCentroidCoordinate));
}

@end
