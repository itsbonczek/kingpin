# Kingpin as dynamic framework

If you want to use Kingpin as framework be sure to read the following articles:

- [How to export “fat” Cocoa Touch Framework (for Simulator and Device)?](http://stackoverflow.com/questions/29634466/how-to-export-fat-cocoa-touch-framework-for-simulator-and-device/31270427#31270427)
- [Stripping Unwanted Architectures From Dynamic Libraries In Xcode](http://ikennd.ac/blog/2015/02/stripping-unwanted-architectures-from-dynamic-libraries-in-xcode/)

(these links address issue: [Error when uploading on iTunes Connect #96](https://github.com/itsbonczek/kingpin/issues/96))

## How to build framework on your own

Also if you can build it yourself: root folder of repository contains `build.sh` script. Try running without arguments:

```
./build.sh
```

To build frameworks use:

```
./build.sh distribute
```
