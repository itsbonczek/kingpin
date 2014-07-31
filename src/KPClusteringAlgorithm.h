//
//  KPClusteringAlgorithm.h
//  kingpin
//
//  Created by Bryan Bonczek on 6/1/14.
//
//

#import <Foundation/Foundation.h>
#import "KPAnnotationTree.h"

@protocol KPClusteringAlgorithm <NSObject>

- (NSArray *)clusterAnnotationsInMapRect:(MKMapRect)mapRect
                           parentMapView:(MKMapView *)mapView
                          annotationTree:(KPAnnotationTree *)annotationTree;

@end
