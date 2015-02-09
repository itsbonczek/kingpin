# kingpin

A drop-in MKAnnotation clustering library for iOS.

[![Build Status](https://travis-ci.org/itsbonczek/kingpin.svg?branch=master)](https://travis-ci.org/itsbonczek/kingpin)

__Update February 1, 2015__

Kingpin is now 0.2. 

If you are coming from 0.1, be sure to review README for changes.

## Features

* Uses a [2-d tree](http://en.wikipedia.org/wiki/K-d_tree) under the hood for maximum performance.
* No subclassing required, making the library easy to integrate with existing projects.

## Installation

Install via CocoaPods. To get stable release in your `Podfile` add:

```ruby
pod 'kingpin'
```

then run 

```bash
pod install
```

If you want to use the latest version from kingpin's master, point your Podfile to the git:

```
pod 'kingpin', :git => 'https://github.com/itsbonczek/kingpin'
```

## Basic usage

Create an instance of `KPClusteringController`. You'll likely want to do this inside a view controller containing a map view.

```objective-c
self.clusteringController = [[KPClusteringController alloc] initWithMapView:self.mapView]
```

Set the controller's annotations:

```objective-c
[self.clusteringController setAnnotations:[self annotations]];
```

Handle the clusters:

```objective-c
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    MKPinAnnotationView *annotationView = nil;
    
    if ([annotation isKindOfClass:[KPAnnotation class]]) {
        KPAnnotation *kingpinAnnotation = (KPAnnotation *)annotation;
        
        if ([kingpinAnnotation isCluster]) {
            annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"cluster"];
            
            if (annotationView == nil) {
                annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:kingpinAnnotation reuseIdentifier:@"cluster"];
            }
            
            annotationView.pinColor = MKPinAnnotationColorPurple;
        } else {
            annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
            
            if (annotationView == nil) {
                annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:[kingpinAnnotation.annotations anyObject] reuseIdentifier:@"pin"];
            }
            
            annotationView.pinColor = MKPinAnnotationColorRed;
        }
        
        annotationView.canShowCallout = YES;
    }
    
    return annotationView;
}
```

Customize the annotations:
```
- (void)clusteringController:(KPClusteringController *)clusteringController configureAnnotationForDisplay:(KPAnnotation *)annotation {
    annotation.title = [NSString stringWithFormat:@"%lu custom annotations", (unsigned long)annotation.annotations.count];
    annotation.subtitle = [NSString stringWithFormat:@"%.0f meters", annotation.radius];
}
```


Also, see example on how to use kingpin with your own custom annotations in [Wiki/Examples](https://github.com/itsbonczek/kingpin/wiki/Examples).

__Note:__ You can gain access to the cluster's annotations via `-[KPAnnotation annotations]`.

Refresh visible annotations as needed:

```objective-c
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [self.clusteringController refresh:self.animationSwitch.on];
}
```

This is typically done in `-mapView:regionDidChangeAnimated:`

__Note:__  The refresh method checks if the map is visible and if the viewport has significantly changed. In some specific cases, it might be useful to force a refresh without doing the checks. The method `-(void)refresh:(BOOL)animated force:(BOOL)force` of KPClusteringController with force = YES will do that. This method can become CPU heavy and should be used in specific cases.

## Configuration

To configure the clustering algorithm, create an instance of KPGridClusteringAlgorithm and use it to instantiate a KPClusteringController:

```objective-c
KPGridClusteringAlgorithm *algoritm = [KPGridClusteringAlgorithm new];

algorithm.gridSize = CGSizeMake(50, 50); // cluster grid cell size
algorithm.annotationSize = CGSizeMake(25, 50); // annotation view size
algorithm.clusteringStrategy = KPGridClusteringAlgorithmStrategyTwoPhase;

KPClusteringController *clusteringController = [[KPClusteringController alloc] initWithMapView:self.mapView clusteringAlgorithm:algorithm];
```

## Clustering algorithm

Kingpin uses simple grid-based clustering algorithm backed by k-d tree.

The good demonstration of this algorithm can be found in WWDC Session 2011: ["Visualizing Information Geographically with MapKit"](https://developer.apple.com/videos/wwdc/2011/).

Kingpin's algorithm works in two steps (phases): 

1. The first step produces a cluster grid by querying a 2-d tree.
2. The second step merges clusters in this cluster grid that visually overlap.

## Versions

See [CHANGELOG](https://github.com/itsbonczek/kingpin/blob/master/CHANGELOG.md) for details. All versions are tagged accordingly.

## Demo

Check out the **tester** target in *kingpin.xcodeproj*

## Licence

Apache 2.0

