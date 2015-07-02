# Kingpin Documentation

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](http://doctoc.herokuapp.com/)*

- [Basic usage (Objective-C)](#basic-usage-objective-c)
- [Basic usage (Swift)](#basic-usage-swift)
- [Customize the annotations](#customize-the-annotations)
- [Accessing cluster's annotations](#accessing-clusters-annotations)
- [Refreshing visible annotations](#refreshing-visible-annotations)
- [Configuration](#configuration)
- [How it works: clustering algorithm](#how-it-works-clustering-algorithm)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Basic usage (Objective-C)

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

## Basic usage (Swift)

Create an instance of `KPClusteringController`. You'll likely want to do this inside a view controller containing a map view.

```swift
class ViewController: NSViewController {
    private var clusteringController : KPClusteringController!
    @IBOutlet weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let algorithm : KPGridClusteringAlgorithm = KPGridClusteringAlgorithm()

        algorithm.annotationSize = CGSizeMake(25, 50)
        algorithm.clusteringStrategy = KPGridClusteringAlgorithmStrategy.TwoPhase;

        clusteringController = KPClusteringController(mapView: self.mapView, clusteringAlgorithm: algorithm)
        clusteringController.delegate = self // If you want to use delegate methods
```

Set the controller's annotations:

```swift
        clusteringController.setAnnotations(annotations())
```

Handle the clusters:

```swift
func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
    if annotation is MKUserLocation {
        // return nil so map view draws "blue dot" for standard user location
        return nil
    }

    var annotationView : MKPinAnnotationView?

    if annotation is KPAnnotation {
        let a = annotation as! KPAnnotation

        if a.isCluster() {
            annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("cluster") as? MKPinAnnotationView

            if (annotationView == nil) {
                annotationView = MKPinAnnotationView(annotation: a, reuseIdentifier: "cluster")
            }

            annotationView!.pinColor = .Purple
        }

        else {
            annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("pin") as? MKPinAnnotationView

            if (annotationView == nil) {
                annotationView = MKPinAnnotationView(annotation: a, reuseIdentifier: "pin")
            }

            annotationView!.pinColor = .Red
        }

        annotationView!.canShowCallout = true;
    }

    return annotationView;
}

func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
    clusteringController.refresh(false) // "false" because animations are not supported on OSX yet
}
```

## Customize the annotations

```
- (void)clusteringController:(KPClusteringController *)clusteringController configureAnnotationForDisplay:(KPAnnotation *)annotation {
    annotation.title = [NSString stringWithFormat:@"%lu custom annotations", (unsigned long)annotation.annotations.count];
    annotation.subtitle = [NSString stringWithFormat:@"%.0f meters", annotation.radius];
}
```

For more information on how to use kingpin with your own custom annotations see [FAQ](https://github.com/itsbonczek/kingpin/blob/master/Documentation/FAQ.md).


## Accessing cluster's annotations

__Note:__ You can gain access to the cluster's annotations via `-[KPAnnotation annotations]`.

## Refreshing visible annotations

This is typically done in `-mapView:regionDidChangeAnimated:`:

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


