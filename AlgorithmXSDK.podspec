Pod::Spec.new do |s|
  s.name          = 'AlgorithmXSDK'
  s.version       = '1.0.1'
  s.summary       = 'AlgorithmX SDK for iOS: customer events, push notifications and in-app campaigns.'
  s.homepage      = 'https://github.com/algorithmx-cloud/algorithmx-ios-sdk'
  s.license       = { :type => 'MIT', :file => 'LICENSE' }
  s.author        = { 'AlgorithmX' => 'hello@algorithmx.cloud' }
  s.platform      = :ios, '15.0'
  s.swift_version = '5.9'

  # Same sources as Package.swift. CocoaPods trunk stops accepting new pods on
  # December 2, 2026, so apps install this pod from the Git tag:
  #   pod 'AlgorithmXSDK', :git => 'https://github.com/algorithmx-cloud/algorithmx-ios-sdk.git', :tag => '1.0.1'
  s.source        = { :git => 'https://github.com/algorithmx-cloud/algorithmx-ios-sdk.git', :tag => s.version.to_s }
  s.source_files  = 'Sources/AlgorithmXSDK/**/*.swift'
  # Apple privacy manifest: collected data and UserDefaults reasons.
  s.resource_bundles = { 'AlgorithmXSDK_Privacy' => ['Sources/AlgorithmXSDK/PrivacyInfo.xcprivacy'] }

  s.frameworks    = 'UIKit', 'WebKit', 'UserNotifications', 'Network'
  s.library       = 'sqlite3'
end
