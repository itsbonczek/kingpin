//
//  kingpin_OSXTests.m
//  kingpin-OSXTests
//
//  Created by Stanislaw Pankevich on 27/06/15.
//
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

@interface kingpin_OSXTests : XCTestCase

@end

@implementation kingpin_OSXTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
