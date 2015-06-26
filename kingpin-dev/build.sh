#!/bin/sh

reveal_archive_in_finder=true

project="kingpin.xcodeproj"
framework_name="kingpin"
framework="${framework_name}.framework"

unit_tests_scheme="kingpin-Unit-Tests-iOS"
ios_scheme="${framework_name}-iOS"
ios_example_scheme=Example-iOS
# osx_scheme="${framework_name}-OSX"
# osx_example_scheme="Example-OSX"

project_dir=${PROJECT_DIR:-$(pwd)}
build_dir=${BUILD_DIR:-Build}
configuration=${CONFIGURATION:-Release}

ios_simulator_path="${build_dir}/${ios_scheme}/${configuration}-iphonesimulator"
ios_simulator_binary="${ios_simulator_path}/${framework}/${framework_name}"

ios_device_path="${build_dir}/${ios_scheme}/${configuration}-iphoneos"
ios_device_binary="${ios_device_path}/${framework}/${framework_name}"

ios_universal_path="${build_dir}/${ios_scheme}/${configuration}-iphoneuniversal"
ios_universal_framework="${ios_universal_path}/${framework}"
ios_universal_binary="${ios_universal_path}/${framework}/${framework_name}"

ios_example_device_path="${build_dir}/${ios_example_scheme}/${configuration}-iphoneos"
ios_example_device_binary="${ios_example_device_path}/${ios_example_scheme}.app"

ios_example_simulator_path="${build_dir}/${ios_example_scheme}/${configuration}-iphonesimulator"
ios_example_simulator_binary="${ios_example_simulator_path}/${ios_example_scheme}.app"

osx_example_path="${build_dir}/${osx_example_scheme}/${configuration}-macosx"
osx_example_binary="${osx_example_path}/${osx_example_scheme}.app"

# osx_path="${build_dir}/${osx_scheme}/${configuration}-macosx"
# osx_framework="${osx_path}/${framework}"

distribution_path="${project_dir}/../Distribution"
distribution_path_ios="${distribution_path}/iOS"
# distribution_path_osx="${distribution_path}/OSX"


usage() {
cat <<EOF
Usage: sh $0 command
command:
  print_configuration         print all configuration variables
  run_unit_tests              run unit tests
  build_ios                   build iOS for device and simulator and create universal iOS framework
  export_built_frameworks     export built frameworks to distribution folder
  validate_ios                validate universal iOS framework against Example-iOS application
  distribute                  run tests, build iOS frameworks, validate iOS frameworks
EOF
}


run() {
    echo "Running command: $@"
    eval $@ || {
		echo "Command failed: \"$@\""
        exit 1
    }
}


print_configuration() {
    cat <<EOF
Project:                  $project
Scheme iOS:               $ios_scheme
Project dir:              $project_dir
Build dir:                $build_dir
Configuration:            $configuration
Framework                 $framework

iOS Simulator build path: $ios_simulator_path
iOS Device build path:    $ios_device_path
iOS Universal build path: $ios_universal_path
iOS Universal framework:  $ios_universal_framework

Distribution path:        $distribution_path"
Distribution path (iOS):  $distribution_path_ios"
EOF
}


clean_build_folder() {
    rm -rf "${build_dir}"
    mkdir -p "${build_dir}"
}


run_unit_tests() {
	run xcodebuild -project ${project} \
                   -scheme ${unit_tests_scheme} \
                   -sdk iphonesimulator \
                   clean test
}


build_ios() {
    run xcodebuild -project ${project} \
                   -scheme ${ios_scheme} \
                   -sdk iphonesimulator \
                   -configuration ${configuration} \
                   CONFIGURATION_BUILD_DIR=${ios_simulator_path} \
                   clean build 

    run xcodebuild -project ${project} \
                   -scheme ${ios_scheme} \
                   -sdk iphoneos \
                   -configuration ${configuration} \
                   CONFIGURATION_BUILD_DIR=${ios_device_path} \
                   clean build

    rm -rf "${ios_universal_path}"
    mkdir "${ios_universal_path}"

    mkdir -p "${ios_universal_framework}"

    cp -av "${ios_device_path}/." "${ios_universal_path}"

    run lipo "${ios_simulator_binary}" "${ios_device_binary}" -create -output "${ios_universal_binary}"
}


# build_osx() {
#     run xcodebuild -project ${project} \
#                    -scheme ${osx_scheme} \
#                    -sdk macosx \
#                    -configuration ${configuration} \
#                    CONFIGURATION_BUILD_DIR=${osx_path} \
#                    clean build
# }


export_built_frameworks() {
    rm -rf "$distribution_path"
    mkdir -p "$distribution_path_ios"
    # mkdir -p "$distribution_path_osx"

    cp -av "${ios_universal_framework}" "${distribution_path_ios}"
    # cp -av "${osx_framework}" "${distribution_path_osx}"
}


validate_ios() {

    # Build Example iOS app against simulator
    run xcodebuild -project ${project} \
                   -target ${ios_example_scheme} \
                   -sdk iphonesimulator \
                   -configuration ${configuration} \
                   CONFIGURATION_BUILD_DIR=${ios_example_simulator_path} \
                   clean build

    # Build Example iOS app against device
    run xcodebuild -project ${project} \
                   -target ${ios_example_scheme} \
                   -sdk iphoneos \
                   -configuration ${configuration} \
                   CONFIGURATION_BUILD_DIR=${ios_example_device_path} \
                   clean build

    run codesign -vvvv --verify --deep ${ios_example_device_binary}

    # How To Perform iOS App Validation From the Command Line
    # http://stackoverflow.com/questions/7568420/how-to-perform-ios-app-validation-from-the-command-line
    run xcrun -v -sdk iphoneos Validation ${ios_example_device_binary}

    # # Build Example OSX app
    # run xcodebuild -project ${project} \
    #                -target ${osx_example_scheme} \
    #                -sdk macosx \
    #                -configuration ${configuration} \
    #                CONFIGURATION_BUILD_DIR=${osx_example_path} \
    #                clean build
    #
    # run codesign -vvvv --verify --deep ${osx_example_binary}
}


open_distribution_folder() {
    if [ ${reveal_archive_in_finder} = true ]; then
        open "${distribution_path}"
    fi
}


distribute() {
	clean_build_folder
	# run_unit_tests
	build_ios
	# build_osx
	export_built_frameworks
	validate_ios
	open_distribution_folder
}


# Show usage instructions if no arguments passed
if [ "$#" -eq 0 -o "$#" -gt 2 ]; then
    usage
    exit 1
fi

# This is needed for commands like: "./build.sh distribute" to work from command line, outside this script
if type -t $@ | grep "function" &> /dev/null; then
	$@
else
    echo "Command '$@' not found"	
fi
	
	


