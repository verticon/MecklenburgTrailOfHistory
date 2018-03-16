workspace 'Trail of History'

use_frameworks!  # Comment this line if you're not using Swift

platform :ios, '11.0'

target 'Trail of History' do

    project './Trail of History.xcodeproj'

    pod 'Firebase/Core'
    pod 'Firebase/Database'
    pod 'Firebase/Auth'
    pod 'VerticonsToolbox'

    target 'Trail of History Tests' do

        inherit! :search_paths
        pod 'Firebase'
        pod 'VerticonsToolbox'

    end

end

target 'UserPath' do

    project './UserPath.xcodeproj'

    pod 'VerticonsToolbox'

end

