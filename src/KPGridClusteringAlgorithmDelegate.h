//
//  KPGridClusteringAlgorithmDelegate.h
//  kingpin
//
//  Created by Stanislaw Pankevich on 12/04/14.
//
//

#import <Foundation/Foundation.h>

@class KPAnnotation;

@protocol KPGridClusteringAlgorithmDelegate <NSObject>
- (BOOL)clusterIntersects:(KPAnnotation *)clusterAnnotation anotherCluster:(KPAnnotation *)anotherClusterAnnotation;
@end
