# Kingpin CHANGELOG

## 0.2.beta

### Changed

* Much faster tree building algorithm for KPAnnotationTree is introduced.
* KPAnnotation was rewritten to use iterative preorder instead of recursion for tree traversal (#51, thanks @sammio2).
* Clustering algorithm is extracted into separate class KPGridClusteringAlgorithm.
* Unit-tests are added. The project is now built on Travis.

### Fixed

* Fixed bug on attempts to use Kingpin with map view with zero rect.

## Versions 0.1.3-0.1.4

### Fixed

* Bug with cluster grid not freed correctly (#41)

## Version 0.1.2

### Added

* support for 3D maps

## Version 0.1.1

### Added

* support for multiple tree controllers

## Versions prior to 0.1.1

Long-long history undocumented...

