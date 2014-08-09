//
//  Datasets.h
//  kingpin
//
//  Created by Stanislaw Pankevich on 31/07/14.
//
//

#import "TestAnnotation.h"

static inline NSArray *dataset1_8000_Moscow() {

    // build an NYC and SF cluster

    NSString *filePath = [[NSBundle bundleForClass:[TestAnnotation class]] pathForResource:@"Dataset1" ofType:@"txt"];
    NSData *JSONData = [[NSData alloc] initWithContentsOfFile:filePath];

    //    NSLog(@"%@", JSONData);

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

static inline NSArray *dataset2_random_NY_and_SF() {
    // build an NYC and SF cluster

    CLLocationCoordinate2D NYCoord = CLLocationCoordinate2DMake(40.77, -73.98);
    CLLocationCoordinate2D SFCoord = CLLocationCoordinate2DMake(37.85, -122.68);

    NSMutableArray *annotations = [NSMutableArray array];

    CLLocationCoordinate2D nycCoord = NYCoord;
    CLLocationCoordinate2D sfCoord = SFCoord;

    for (int i = 0; i < 100 / 2; i++) {

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
