Pod::Spec.new do |s|
  s.name         = "kingpin"
  s.version      = "0.1.0"
  s.summary      = "A drop-in MKAnnotation clustering library for iOS."
  s.description  = "A drop-in MKAnnotation clustering library for iOS."
  s.homepage     = "http://itsbonczek.github.com/kingpin"

  s.license      = 'Apache 2.0'
  s.author       = { "itsbonczek" => "bonczek@gmail.com" }
  s.source       = { :git => "https://github.com/itsbonczek/kingpin.git", :tag => "0.1.0" }

  s.platform     = :ios

  s.source_files = 'src/*.{h,m}'

  s.frameworks = 'MapKit', 'CoreLocation'

  s.requires_arc = true

end
