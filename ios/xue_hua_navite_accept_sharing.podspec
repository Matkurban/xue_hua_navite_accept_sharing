#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint xue_hua_navite_accept_sharing.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_navite_accept_sharing'
  s.version          = '1.0.0'
  s.summary          = 'Cross-platform Flutter plugin to receive shared text, URLs, and arbitrary files.'
  s.description      = <<-DESC
Cross-platform Flutter plugin to receive shared text, URLs, and arbitrary files across Android, iOS, macOS, Windows, Linux, and Web.
                       DESC
  s.homepage         = 'https://github.com/Matkurban'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Matkurban' => '3496354336@qq.com' }
  s.source           = { :path => '.' }
  s.source_files = 'xue_hua_navite_accept_sharing/Sources/xue_hua_navite_accept_sharing/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'xue_hua_navite_accept_sharing_privacy' => ['xue_hua_navite_accept_sharing/Sources/xue_hua_navite_accept_sharing/PrivacyInfo.xcprivacy']}
end
