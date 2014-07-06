# kingpin

A drop-in MKAnnotation clustering library for iOS.

[![Build Status](https://travis-ci.org/itsbonczek/kingpin.svg?branch=master)](https://travis-ci.org/itsbonczek/kingpin)

__Update July 6, 2014__

The current master branch contains the newest kingpin which is backward-incompatible with the latest stable version of kingpin: [0.1.4](https://github.com/itsbonczek/kingpin/releases). We are planning 0.2 release very soon.

## Features

* Uses a [2-d tree](http://en.wikipedia.org/wiki/K-d_tree) under the hood for maximum performance.
* No subclassing required, making the library easy to integrate with existing projects.

## Installation

Install via CocoaPods. In your `Podfile` add:

```ruby
pod 'kingpin'
```

then run 

```bash
pod install
```

## Basic usage

Create an instance of a KPClusteringController. The most likely you want to do this inside a view controller which has map view.

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

Also, see example on how to use kingpin with your own custom annotations in [Wiki/Examples](https://github.com/itsbonczek/kingpin/wiki/Examples).

__Note:__ You can gain access to the cluster's annotations via `-[KPAnnotation annotations]`.

Refresh visible annotations as needed:

```objective-c
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [self.clusteringController refresh:self.animationSwitch.on];
}
```

This is typically done in `-mapView:regionDidChangeAnimated:`

## Configuration

To perform configuration of clustering algorithm create an instance of KPGridClusteringAlgorithm and use it to instantiate KPClusteringController:

```objective-c
KPGridClusteringAlgorithm *algoritm = [KPGridClusteringAlgorithm new];

algorithm.gridSize = CGSizeMake(50, 50); // cluster grid cell size
algorithm.annotationSize = CGSizeMake(25, 50); // annotation view size
algorithm.clusteringStrategy = KPGridClusteringAlgorithmStrategyTwoPhase;

KPClusteringController *clusteringController = [[KPClusteringController alloc] initWithMapView:self.mapView clusteringAlgorithm:algorithm];
```

## Clustering algorithm

Currently kingpin uses simple grid-based clustering algorithm backed by k-d tree.

The good demonstration of this algorithm can be found in WWDC Session 2011: ["Visualizing Information Geographically with MapKit"](https://developer.apple.com/videos/wwdc/2011/).

Kingpin's algorithm works in two steps: 

1. At the first step it produces a cluster grid.
2. At the second step algorithm performs a merger of the clusters in this cluster grid that visually overlap.

## Versions

See [CHANGELOG](https://github.com/itsbonczek/kingpin/blob/master/CHANGELOG.md) for details. All versions are tagged accordingly.

## Demo

Check out the **tester** target in *kingpin.xcodeproj*

## Licence

Apache 2.0

