# kingpin

A drop-in MKAnnotation clustering library for iOS.

[![Build Status](https://travis-ci.org/itsbonczek/kingpin.svg?branch=master)](https://travis-ci.org/itsbonczek/kingpin)

__Update July 2, 2015__

Kingpin is now 0.3.0-beta, the following features are under test:

- Carthage support
- OSX support (no animations support yet)
- Dynamic frameworks: iOS and OSX
- 4 example apps: iOS, OSX, iOS-Swift, OSX-Swift.

## Features

* Uses a [2-d tree](http://en.wikipedia.org/wiki/K-d_tree) under the hood for maximum performance.
* No subclassing required, making the library easy to integrate with existing projects.

## Installation

### Cocoa Pods

To get stable release in your `Podfile` add:

```ruby
pod 'kingpin'
```

If you want to use the latest version from kingpin's master, point your Podfile to the git:

```
pod 'kingpin', :git => 'https://github.com/itsbonczek/kingpin'
```

### Carthage

In Cartfile add:

```
github "itsbonczek/kingpin"
```

## FAQ

See [FAQ](https://github.com/itsbonczek/kingpin/blob/master/Documentation/FAQ.md).

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

For more information on how to use kingpin with your own custom annotations see [FAQ](https://github.com/itsbonczek/kingpin/blob/master/Documentation/FAQ.md).

__Note:__ You can gain access to the cluster's annotations via `-[KPAnnotation annotations]`.

Refresh visible annotations as needed, this is typically done in `-mapView:regionDidChangeAnimated:`:

```objective-c
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [self.clusteringController refresh:self.animationSwitch.on];
}
```

__Note:__  The refresh method checks if the map is visible and if the viewport has significantly changed. In some specific cases, it might be useful to force a refresh without doing the checks. The method `-(void)refresh:(BOOL)animated force:(BOOL)force` of KPClusteringController with force = YES will do that. This method can become CPU heavy and should be used in specific cases.

## Configuration

To configure the clustering algorithm, create an instance of KPGridClusteringAlgorithm and use it to instantiate a KPClusteringController:

```objective-c
KPGridClusteringAlgorithm *algorithm = [KPGridClusteringAlgorithm new];

algorithm.gridSize = CGSizeMake(50, 50); // cluster grid cell size
algorithm.annotationSize = CGSizeMake(25, 50); // annotation view size
algorithm.clusteringStrategy = KPGridClusteringAlgorithmStrategyTwoPhase;

KPClusteringController *clusteringController = [[KPClusteringController alloc] initWithMapView:self.mapView clusteringAlgorithm:algorithm];
```

## How it works: clustering algorithm

Kingpin uses simple grid-based clustering algorithm backed by a 2-d tree. KPClusteringController uses a 2-d tree to store annotations. 2-d (or more generically, [k-d]( http://en.wikipedia.org/wiki/K-d_tree)) trees are designed for fast range based queries (i.e. give me all annotations that lie within a given bounding box).

Kingpin's algorithm works in two steps (phases): 

1) The first step produces a cluster grid by querying a 2-d tree.

Every time -refresh gets called on the clustering controller, the controller splits the current map visible map view into a grid (controlled by the gridSize property), and for each square of the grid performs a query on the 2-d tree for all annotations within the square. The annotations for each square are consolidated into a single KPAnnotation.

A good demonstration of this algorithm can be found in WWDC Session 2011: ["Visualizing Information Geographically with MapKit"](https://developer.apple.com/videos/wwdc/2011/).

2) The second step merges clusters in this cluster grid that visually overlap.

Note: step 2 may have negative performance consequences for large numbers of annotations. You can disable the second phase by setting KPGridClusteringAlgorithm's ```clusteringStrategy``` property to ```KPGridClusteringAlgorithmStrategyBasic```

## Versions

See [CHANGELOG](https://github.com/itsbonczek/kingpin/blob/master/CHANGELOG.md) for details. All versions are tagged accordingly.

## Demo

Check out the **tester** target in *kingpin.xcodeproj*

## Licence

Apache 2.0

