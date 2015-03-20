
Pod::Spec.new do |s|
  s.name         = "kingpin"
  s.version      = "0.2.4"
  s.summary      = "A drop-in MapKit/MKAnnotation pin clustering library for MKMapView on iOS."
  s.homepage     = "https://github.com/itsbonczek/kingpin"
  s.author       = { "Bryan Bonczek" => "bonczek@gmail.com" }
  s.license      = 'Apache 2.0'
  s.source       = { :git => "https://github.com/itsbonczek/kingpin.git", :tag => s.version.to_s }
  s.platform     = :ios, 6.0
  s.source_files = 'src/*.{h,m}'
  s.requires_arc = true
  s.frameworks   = 'MapKit', 'CoreLocation'
end
