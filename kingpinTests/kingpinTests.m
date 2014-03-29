//
//  kingpinTests.m
//  kingpinTests
//
//  Created by Stanislaw Pankevich on 08/03/14.
//
//

#import <SenTestingKit/SenTestingKit.h>

#import "KPAnnotationTree.h"
#import "KPAnnotationTree_Private.h"

#import "TestAnnotation.h"

// https://github.com/EvgenyKarkan/EKAlgorithms/blob/master/EKAlgorithms/NSArray%2BEKStuff.m
NSArray *arrayShuffle(NSArray *array) {
    NSUInteger i = array.count;
    NSMutableArray *shuffledArray = [array mutableCopy];

    while (i) {
        NSUInteger randomIndex = arc4random_uniform((u_int32_t)i);
        [shuffledArray exchangeObjectAtIndex:randomIndex withObjectAtIndex:--i];
    }

    return [shuffledArray copy];
}


static inline double randomWithinRange(double min, double max) {
    return min + (max - min) * (double)arc4random_uniform(UINT32_MAX) / (UINT32_MAX - 1);
}


@interface kingpinTests : SenTestCase
@end

static NSUInteger const kNumberOfTestAnnotations = 50000;

@implementation kingpinTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testIntegrityOfAnnotationTree
{
    // build an NYC and SF cluster

    CLLocationCoordinate2D NYCoord = CLLocationCoordinate2DMake(40.77, -73.98);
    CLLocationCoordinate2D SFCoord = CLLocationCoordinate2DMake(37.85, -122.68);

    NSMutableArray *annotations = [NSMutableArray array];

    CLLocationCoordinate2D nycCoord = NYCoord;
    CLLocationCoordinate2D sfCoord = SFCoord;

    for (int i=0; i < kNumberOfTestAnnotations / 2; i++) {

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

    KPAnnotationTree *annotationTree = [[KPAnnotationTree alloc] initWithAnnotations:annotations];

    NSArray *annotationsBySearch = [annotationTree annotationsInMapRect:MKMapRectWorld];

    __block __weak void (^weakRecursiveTraversalBlock)(kp_treenode_t *node, NSUInteger levelOfDepth);
    void (^recursiveTraversalBlock)(kp_treenode_t *node, NSUInteger levelOfDepth);

    __block NSUInteger numberOfNodes = 0;

    weakRecursiveTraversalBlock = recursiveTraversalBlock = ^(kp_treenode_t *node, NSUInteger levelOfDepth) {
        numberOfNodes++;

        NSUInteger XorY = (levelOfDepth % 2) == 0;

        if (node->left) {
            if (XorY) {
                STAssertTrue(node->left->mapPoint.x < node->mapPoint.x, nil);
            } else {
                STAssertTrue(node->left->mapPoint.y < node->mapPoint.y, nil);
            }

            weakRecursiveTraversalBlock(node->left, levelOfDepth + 1);
        }

        if (node->right) {
            if (XorY) {
                STAssertTrue(node->mapPoint.x <= node->right->mapPoint.x, nil);
            } else {
                STAssertTrue(node->mapPoint.y <= node->right->mapPoint.y, nil);
            }

            weakRecursiveTraversalBlock(node->right, levelOfDepth + 1);
        }
    };

    recursiveTraversalBlock(annotationTree.root, 0);

    STAssertTrue(kNumberOfTestAnnotations == annotations.count, nil);
    STAssertTrue(kNumberOfTestAnnotations == annotationsBySearch.count, nil);
    STAssertTrue(kNumberOfTestAnnotations == numberOfNodes, nil);
}

- (void)testEquivalenceOfAnnotationTrees
{
    // build an NYC and SF cluster

    CLLocationCoordinate2D NYCoord = CLLocationCoordinate2DMake(40.77, -73.98);
    CLLocationCoordinate2D SFCoord = CLLocationCoordinate2DMake(37.85, -122.68);

    NSMutableArray *annotations = [NSMutableArray array];

    CLLocationCoordinate2D nycCoord = NYCoord;
    CLLocationCoordinate2D sfCoord = SFCoord;

    for (int i=0; i < kNumberOfTestAnnotations / 2; i++) {

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

    // Create array of shuffled annotations and ensure integrity.
    NSArray *shuffledAnnotations = arrayShuffle(annotations);

    NSAssert(annotations.count == shuffledAnnotations.count, nil);

    NSSet *annotationSet = [NSSet setWithArray:annotations];
    NSSet *shuffledAnnotationSet = [NSSet setWithArray:shuffledAnnotations];

    NSAssert([annotationSet isEqual:shuffledAnnotationSet], nil);


    // Build to two different trees based on original and shuffled annotations arrays.
    KPAnnotationTree *annotationTree1 = [[KPAnnotationTree alloc] initWithAnnotations:annotations];
    KPAnnotationTree *annotationTree2 = [[KPAnnotationTree alloc] initWithAnnotations:shuffledAnnotations];

    NSArray *annotationsBySearch1 = [annotationTree1 annotationsInMapRect:MKMapRectWorld];
    NSArray *annotationsBySearch2 = [annotationTree2 annotationsInMapRect:MKMapRectWorld];

    NSSet *annotationSetBySearch1 = [NSSet setWithArray:annotationsBySearch1];
    NSSet *annotationSetBySearch2 = [NSSet setWithArray:annotationsBySearch2];

    STAssertTrue([annotationSetBySearch1 isEqual:annotationSetBySearch2], nil);
    STAssertTrue([annotationSetBySearch1 isEqual:annotationSet], nil);
    STAssertTrue(annotationsBySearch1.count == kNumberOfTestAnnotations, nil);

    // Create random rect
    double randomWidth = randomWithinRange(0, MKMapRectWorld.size.width);
    double randomHeight = randomWithinRange(0, MKMapRectWorld.size.height);
    double randomX = randomWithinRange(0, MKMapRectWorld.size.width - randomWidth);
    double randomY = randomWithinRange(0, MKMapRectWorld.size.height - randomHeight);

    MKMapRect randomRect = MKMapRectMake(randomX, randomY, randomWidth, randomHeight);

    NSAssert(MKMapRectContainsRect(MKMapRectWorld, randomRect), nil);

    annotationsBySearch1 = [annotationTree1 annotationsInMapRect:randomRect];
    annotationsBySearch2 = [annotationTree2 annotationsInMapRect:randomRect];

    annotationSetBySearch1 = [NSSet setWithArray:annotationsBySearch1];
    annotationSetBySearch2 = [NSSet setWithArray:annotationsBySearch2];

    STAssertTrue([annotationSetBySearch1 isEqual:annotationSetBySearch2], nil);
}

@end
