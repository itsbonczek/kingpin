//
//  KPConfiguration.h
//  kingpin
//
//  Created by Stanislaw Pankevich on 21/04/14.
//
//


#import <Foundation/Foundation.h>

@interface KPConfiguration : NSObject

@property (assign, nonatomic) CGSize gridSize;
@property (assign, nonatomic) CGSize annotationSize;
@property (assign, nonatomic) CGPoint annotationCenterOffset;
@property (assign, nonatomic) CGFloat animationDuration;
@property (assign, nonatomic) UIViewAnimationOptions animationOptions;
@property (assign, nonatomic) BOOL clusteringEnabled;

@end
