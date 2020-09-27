#
# Cookbook Name:: xcode
# Resource:: app
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=begin
#<
Install Xcode app.

@section Notes
* `/Applications/Xcode.app` will still need to be addressed (ex: symlink an installed version)
* `xcode-select -s <dir>` is run after each install so last verison will be default
* Action of `:nothing` takes no action but useful to have data bag as placeholder

@section Example
For side-by-side installation, create a data bag item for each version.
The data bag needs to provide the following attributes at the very least:
```json
  "id": "7_3_1",
  "app": "Xcode",
  "url": "YOUR URL HERE",
  "checksum": "bb0dedf613e86ecb46ced945913fa5069ab716a0ade1035e239d70dee0b2de1b",
  "action": "install"
```
Then loop and call `xcode_app`:
```ruby
include_recipe 'xcode'

xcode_versions.each do |version|
  xcode = data_bag_item(node['xcode']['app']['data_bag'], version)
  xcode_app xcode['id'] do
    app xcode['app']
    url xcode['url']
    checksum xcode['checksum']
    action xcode['action']
    install_suffix xcode['id']
    install_root node['xcode']['install_root'] unless node['xcode']['install_root'].nil?
    force xcode['force'] unless xcode['force'].nil?
  end
end
```

#>
=end

resource_name :xcode_app
provides :xcode_app

# Properties
#<> @property id Unique string to idenfity installed resource, appended to `install_dir`
property :id, String, name_property: true
#<> @property url Location of DMG to download
property :url, String, required: true
#<> @property checksum Checksum of DMG
property :checksum, String, required: true
#<> @property app Used by `dmg_package`
property :app, String, default: 'Xcode'
#<> @property install_suffix If not empty, appended to install folder when moved within `install_root`
property :install_suffix, [String, nil], default: nil
#<> @property install_root Root folder where Xcode is installed
property :install_root, String, default: '/Applications'
#<> @property force Overwrite any existing install location
property :force, [true, false], default: false

default_action :install

# Actions

#<> @action install Installs Xcode app to `install_root`
action :install do
  return if exist?
  raise unless Chef.node['platform_family'].eql?('mac_os_x')
  install_app
end

#<> @action remove Delete directory based on `install_dir`
action :remove do
  delete_installer_file

  directory install_dir do
    recursive true
    action :delete
  end if exist?
end

#<> @action uninstall Deprecated
action :uninstall do
  action_remove
end

# Helper Methods

action_class do
  # The `accept_eula` function is only called if the function 'install_app' is called.
  def accept_eula
    # Accept the Xcode license, this creates the /Library/Preferences/com.apple.dt.Xcode.plist file
    execute 'Accept xcode license' do
      command "#{install_dir}/Contents/Developer/usr/bin/xcodebuild -license accept"
      only_if do
        if ::File.exist?('/Library/Preferences/com.apple.dt.Xcode.plist')
          curr_vers = shell_out("/usr/libexec/PlistBuddy -c 'Print :IDEXcodeVersionForAgreedToGMLicense' /Library/Preferences/com.apple.dt.Xcode.plist").stdout.chomp
          # For both GM and Beta, this will return 'Major.minor.patch' (where '.patch' is optional)
          next_vers = shell_out("/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' #{install_dir}/Contents/Info.plist").stdout.chomp
          Gem::Version.new(next_vers) > Gem::Version.new(curr_vers)
        else
          true
        end
      end
    end
  end

  # Cleanup the installer file
  def delete_installer_file
    file ::File.join(Chef::Config[:file_cache_path], ::File.basename(new_resource.url)) do
      action :delete
      only_if do
        ::File.exist?(::File.join(Chef::Config[:file_cache_path], ::File.basename(new_resource.url)))
      end
    end
  end

  def exist?
    new_resource.force ? false : ::Dir.exist?(install_dir)
  end

  def install_app
    # If we force the install remove target folder if it exists.
    directory install_dir do
      recursive true
      action :delete
    end if new_resource.force && exist?

    if new_resource.url.end_with?('dmg')
      install_dmg
    else
      raise 'Unsupported package provided Xcode installer must be provided as a DMG'
    end

    accept_eula
    post_install
    delete_installer_file if lazy { ::Dir.exist?(install_dir) }
  end

  def install_dir
    ::File.join(new_resource.install_root, "Xcode#{new_resource.install_suffix ? "_#{new_resource.install_suffix}" : ''}.app")
  end

  def install_dmg
    directory temp_pkg_dir do
      recursive true
    end

    # @TODO: On APFS this doesn't seem to eject the disk
    dmg_package new_resource.app do
      source new_resource.url
      checksum new_resource.checksum
      dmg_name ::File.basename(new_resource.url, '.dmg')
      owner 'root'
      type 'app'
      destination temp_pkg_dir
      action :install
    end

    execute 'Move Xcode app install_dir' do
      command "mv -f #{temp_pkg_dir}/Xcode.app #{install_dir}"
      only_if { ::Dir.exist?("#{temp_pkg_dir}/Xcode.app") }
    end

    # Clean up temp
    directory temp_pkg_dir do
      recursive true
      action :delete
      only_if { ::Dir.exist?(temp_pkg_dir) }
    end
  end

  # The `post_install` function is only called if the function 'install_app' is called.
  def post_install
    ruby_block 'Xcode post_install install packages' do
      block do
        version = shell_out("/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' #{install_dir}/Contents/Info.plist").stdout.chomp
        # xcodebuild -runFirstLaunch introduced in Xcode 9
        if Gem::Version.new(version) >= Gem::Version.new('9.0')
          execute 'Run xcodebuild runFirstLaunch' do
            command "sudo #{install_dir}/Contents/Developer/usr/bin/xcodebuild -runFirstLaunch"
          end
        elsif Gem::Version.new(version) >= Gem::Version.new('8.0')
          # Install any additional packages hiding in the Xcode installation path
          xcode_packages = ::Dir.entries("#{install_dir}/Contents/Resources/Packages/").select { |f| !::File.directory? f }
          xcode_packages.each do |pkg|
            execute "Installing Xcode package [#{pkg}]" do
              command "sudo installer -pkg #{install_dir}/Contents/Resources/Packages/#{pkg} -target /"
            end
          end unless xcode_packages.nil?
        end
      end
      only_if { ::Dir.exist?(install_dir) }
    end

    ruby_block 'Xcode post_install xcode-select' do
      block do
        execute 'xcode-select' do
          command "xcode-select -s #{install_dir}/Contents/Developer"
        end
      end
      only_if { ::Dir.exist?(install_dir) }
    end
  end

  def temp_pkg_dir
    ::File.join(Chef::Config[:file_cache_path], "Xcode_#{new_resource.id}")
  end
end
