Pod::Spec.new do |s|

  s.name     = 'ImojiSDKUI'
  s.version  = '2.0.5'
  s.license  = 'MIT'
  s.summary  = 'iOS UI Widgets for Imoji Integration. Integrate Stickers and custom emojis into your applications easily!'
  s.homepage = 'http://imoji.io/sdk'
  s.authors = {'Nima Khoshini'=>'nima@imojiapp.com', 'Jeff Wang'=>'jeffkwang@gmail.com', 'Alex Hoang'=>'alex@imojiapp.com'}

  s.source   = { :git => 'https://github.com/imojiengineering/imoji-ios-sdk-ui.git', :tag => s.version.to_s }
  s.ios.deployment_target = '7.0'

  s.requires_arc = true

  s.subspec 'CollectionView' do |ss|
    ss.dependency "ImojiSDK/Core"
    ss.dependency "ImojiSDKUI/Common"
    ss.dependency "Masonry"

    ss.ios.source_files = 'Source/CollectionView/**/*.{h,m}'
    ss.ios.public_header_files = 'Source/CollectionView/*.h'
  end

  s.subspec 'Editor' do |ss|
    ss.dependency "ImojiSDK/Core"
    ss.dependency "ImojiSDKUI/Common"
    ss.dependency "Masonry"

    ss.vendored_frameworks = 'Frameworks/ImojiGraphics.framework'

    ss.ios.resource_bundles = {'ImojiEditorAssets' => ['Source/Editor/Resources/Icons/*.png', 'Source/Editor/Resources/Images/*.png']}
  
    ss.ios.source_files = 'Source/Editor/**/*.{h,m}'
    ss.ios.public_header_files = 'Source/Editor/*.h'
    ss.ios.frameworks = ["Accelerate", "GLKit"]
    ss.libraries = 'c++'
  end

  s.subspec 'KeyboardView' do |ss|
    ss.dependency "ImojiSDKUI/CollectionView"
    
    ss.ios.prefix_header_file = 'Source/KeyboardView/Source/IMKeyboard.pch'
    ss.ios.source_files = 'Source/KeyboardView/Source/**/*.{h,m}'
    ss.ios.public_header_files = 'Source/KeyboardView/Source/**/*.h'
    ss.ios.resources = ["Source/KeyboardView/Resources/Fonts/*.otf", "Source/KeyboardView/Resources/StoryBoards/IMQwerty.storyboard", "Source/KeyboardView/Resources/KeyArt.xcassets"]
    ss.ios.resource_bundles = {'ImojiKeyboardAssets' => ['Source/KeyboardView/Resources/Icons/*.png']}

  end

  s.subspec 'Common' do |ss|
    ss.ios.source_files = 'Source/Common/Source/**/*.{h,m}'
    ss.ios.resources = ["Source/Common/Resources/Fonts/*.otf"]
    ss.ios.resource_bundles = {'ImojiUIStrings' => ['Source/Common/Resources/Localization/*.lproj'], 'ImojiUIAssets' => ['Source/Common/Resources/Images/*.*']}

  end
  
end
