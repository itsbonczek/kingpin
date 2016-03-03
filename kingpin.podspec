Pod::Spec.new do |s|
  s.name         = "kingpin"
  s.version      = "0.3.2"
  s.summary      = "A drop-in MapKit/MKAnnotation pin clustering library for MKMapView on iOS."
  s.homepage     = "https://github.com/itsbonczek/kingpin"
  s.author       = { "Bryan Bonczek" => "bonczek@gmail.com" }
  s.license      = 'Apache 2.0'
  s.source       = { :git => "https://github.com/itsbonczek/kingpin.git", :tag => s.version.to_s }
  s.source_files = 'kingpin/*.{h,m}'
  s.requires_arc = true
  s.ios.deployment_target   = '7.0'
  s.osx.deployment_target   = '10.9'
  s.frameworks   = 'MapKit', 'CoreLocation'
end
