//
//  Datasets.h
//  kingpin
//
//  Created by Stanislaw Pankevich on 31/07/14.
//
//

#import "TestAnnotation.h"

@interface KPTestDatasets : NSObject

+ (NSArray *)datasets;

+ (NSArray *)dataset1;
+ (NSArray *)dataset2;
+ (NSArray *)dataset3;

@end

@implementation KPTestDatasets

+ (NSArray *)datasets {
    return @[ self.dataset1, self.dataset2, self.dataset3 ];
}

/**
 NYC and SF
 */
+ (NSArray *)dataset1 {
    // build an NYC and SF cluster

    CLLocationCoordinate2D NYCoord = CLLocationCoordinate2DMake(40.77, -73.98);
    CLLocationCoordinate2D SFCoord = CLLocationCoordinate2DMake(37.85, -122.68);

    NSMutableArray *annotations = [NSMutableArray array];

    CLLocationCoordinate2D nycCoord = NYCoord;
    CLLocationCoordinate2D sfCoord = SFCoord;

    for (int i = 0; i < 20000 / 2; i++) {

        CLLocationDegrees latAdj = ((random() % 100) / 1000.f);
        CLLocationDegrees lngAdj = ((random() % 100) / 1000.f);

        TestAnnotation *a1 = [[TestAnnotation alloc] init];
        a1.coordinate = CLLocationCoordinate2DMake(nycCoord.latitude + latAdj,
                                                   nycCoord.longitude + lngAdj);
        [annotations addObject:a1];

        TestAnnotation *a2 = [[TestAnnotation alloc] init];
        a2.coordinate = CLLocationCoordinate2DMake(sfCoord.latitude + latAdj,
                                                   sfCoord.longitude + lngAdj);
        [annotations addObject:a2];
        
    }
    
    return annotations;
}

/**
 Real dataset provided by developer. Obtained from third-party service.
 */
+ (NSArray *)dataset2 {
    NSString *filePath = [[NSBundle bundleForClass:[TestAnnotation class]] pathForResource:@"Dataset1" ofType:@"txt"];
    NSData *JSONData = [[NSData alloc] initWithContentsOfFile:filePath];

    NSError *error = nil;
    NSArray *pins = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:&error];

    NSMutableArray *annotations = [NSMutableArray array];

    for (NSDictionary *pin in pins) {

        TestAnnotation *a1 = [[TestAnnotation alloc] init];
        double latitude = [pin[@"lat"] doubleValue];
        double longitude = [pin[@"long"] doubleValue];

        a1.coordinate = CLLocationCoordinate2DMake(latitude, longitude);
        [annotations addObject:a1];
    }
    
    return annotations;
}

/**
 5000 equal points
 */
+ (NSArray *)dataset3 {
    CLLocationCoordinate2D zeroCoordinate = CLLocationCoordinate2DMake(0, 0);

    NSMutableArray *annotations = [NSMutableArray array];

    for (int i = 0; i < 5000; i++) {

        TestAnnotation *a = [[TestAnnotation alloc] init];
        a.coordinate = zeroCoordinate;

        [annotations addObject:a];
    }

    return annotations;
}

@end
