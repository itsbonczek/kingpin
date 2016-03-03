# kingpin

A drop-in MKAnnotation clustering library for iOS.

[![Build Status](https://travis-ci.org/itsbonczek/kingpin.svg?branch=master)](https://travis-ci.org/itsbonczek/kingpin)

## Features

* Uses a [2-d tree](http://en.wikipedia.org/wiki/K-d_tree) under the hood for maximum performance.
* No subclassing required, making the library easy to integrate with existing projects.

## Installation

### CocoaPods

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

### Dynamic framework

Frameworks are published to [Github Releases](https://github.com/itsbonczek/kingpin/releases). If you want to use kingpin as framework be sure to read short documentation about using [Kingpin as dynamic framework](https://github.com/itsbonczek/kingpin/blob/master/Documentation/Framework.md).

### Component (experimental, used by maintainers)

Get the latest [component .make file for kingpin](https://github.com/AlexDenisov/Components/tree/master/Components.make/kingpin).

## Documentation

See [Documentation](https://github.com/itsbonczek/kingpin/blob/master/Documentation/Documentation.md) and [FAQ](https://github.com/itsbonczek/kingpin/blob/master/Documentation/FAQ.md).

## Versions

See [CHANGELOG](https://github.com/itsbonczek/kingpin/blob/master/CHANGELOG.md) for details. All versions are tagged accordingly.

## Demo

Check out the **kingpin-examples** project.

## Licence

Apache 2.0

