


namespace :submodules do
  desc "update submodules"
  task :update do
    exec 'git submodule update --recursive'
  end
end

namespace :tests do
  desc "run tests"
  task :run  do
    exec 'lib/xctool/xctool.sh -project ./kingpin.xcodeproj -scheme kingpinTests test -sdk iphonesimulator7.1'
  end
  
end