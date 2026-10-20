#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint xue_hua_navite_accept_sharing.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_navite_accept_sharing'
  s.version          = '0.0.1'
  s.summary          = 'Cross-platform Flutter plugin to receive shared text, URLs, and arbitrary files.'
  s.description      = <<-DESC
Cross-platform Flutter plugin to receive shared text, URLs, and arbitrary files across Android, iOS, macOS, Windows, Linux, and Web.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'xue_hua_navite_accept_sharing/Sources/xue_hua_navite_accept_sharing/**/*'

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '11.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
