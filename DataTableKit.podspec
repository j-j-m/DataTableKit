#
# Be sure to run `pod lib lint DataTableKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DataTableKit'
  s.version          = '0.3.0'
  s.summary          = 'TableKit for when you want to use core data.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'Core Data enabled, Type-safe declarative table views. Swift 2.2 is required.'

  s.homepage         = 'https://github.com/j-j-m/DataTableKit'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Jacob Martin' => 'martinjaco@gmail.com' }
  s.source           = { :git => 'https://github.com/j-j-m/DataTableKit.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'DataTableKit/Classes/**/*'
  
  # s.resource_bundles = {
  #   'DataTableKit' => ['DataTableKit/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
