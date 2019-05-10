name             'xcode'
maintainer       'Roblox'
maintainer_email 'info@roblox.com'
license          'Apache-2.0'
description      'Provides custom resource to install Apple Xcode app and simulators.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '2.2.0'

source_url 'https://github.com/Roblox/chef-xcode'
issues_url 'https://github.com/Roblox/chef-xcode/issues'
chef_version '>= 13.4'

recipe 'xcode::default', 'Includes DMG required by resource'

supports         'mac_os_x'

depends          'dmg'
