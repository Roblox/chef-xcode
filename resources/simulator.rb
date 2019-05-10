#
# Cookbook Name:: xcode
# Library:: simulator
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
Install simulator used by Xcode.
Property `name` is provided by `InstallPrefix` in download index (ex: `/Library/Developer/CoreSimulator/Profiles/Runtimes`)

@section Example
For ease of multiple simulators, create a data bag item for each.
The data bag needs to provide the following attributes at the very least:
```json
  "id": "iOS_10_1",
  "version": "10.1.1.1476902849",
  "name": "iOS 10.1",
  "url": "YOUR URL HERE",
  "checksum": "bb0dedf613e86ecb46ced945913fa5069ab716a0ade1035e239d70dee0b2de1b",
  "action": "install"
````
Then loop and call `xcode_simulator`:
```ruby
simulator_versions = data_bag(node['xcode']['sim']['data_bag'])

simulator_versions.each do |version|
  simulator = data_bag_item(node['xcode']['sim']['data_bag'], version)

  xcode_simulator simulator['name'] do
    url simulator['url']
    checksum simulator['checksum']
    action simulator['action']
  end
end
```

#>
=end

resource_name :xcode_simulator
provides :xcode_simulator

# Properties
#<> @property version Unique string to identify installed simulator
property :version, String, required: true
#<> @property url Location of DMG to download
property :url, String, required: true
#<> @property checksum Checksum of DMG
property :checksum, String, required: true
#<> @property force Overwrite any existing install
property :force, [true, false], default: false

default_action :install

# Actions

#<> @action install Installs simulator
action :install do
  return if exist?
  raise unless Chef.node['platform_family'].eql?('mac_os_x')
  install_simulator
end

# @TODO: Add 'remove' action
#  Deprecate uninstall
#<> @action remove Delete directory based on `install_dir`
action :remove do
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
  def cleanup
    file pkg_path do
      action :delete
      only_if { ::File.exist?(pkg_path) }
    end

    directory "#{pkg_path}.expand" do
      recursive true
      action :delete
      only_if { ::Dir.exist?("#{pkg_path}.expand") }
    end
  end

  def dmg_path
    ::File.join(Chef::Config[:file_cache_path], ::File.basename(new_resource.url))
  end

  def exist?
    new_resource.force ? false : ::Dir.exist?(install_dir)
  end

  def identifier
    ::File.basename(new_resource.url).split('-')[0]
  end

  def install_dir
    "/Library/Developer/CoreSimulator/Profiles/Runtimes/#{new_resource.name}.simruntime"
  end

  def install_package
    directory ::File.dirname(install_dir) do
      recursive true
    end

    execute "Install Simulator package [#{new_resource.name}]" do
      command "installer -pkg #{pkg_path} -target /"
      only_if { ::File.exist?(pkg_path) }
    end
  end

  def install_simulator
    # If we force the install remove target folder if it exists.
    directory install_dir do
      recursive true
      action :delete
    end if new_resource.force && exist?

    if new_resource.url.end_with?('dmg')
      prepare_package
      install_package
      cleanup
    else
      raise 'Unsupported package provided Simulator installer must be provided as a DMG'
    end
  end

  def pkg_path
    ::File.join(Chef::Config[:file_cache_path], "#{::File.basename(identifier)}.pkg")
  end

  def prepare_package
    remote_file dmg_path do
      source new_resource.url
      checksum new_resource.checksum
    end

    execute "Prepare Simulator package [#{new_resource.name}]" do
      cwd Chef::Config[:file_cache_path]
      command <<-EOF
        hdiutil attach '#{dmg_path}' -mountpoint '/Volumes/#{identifier}' -quiet

        # Unpack the package
        rm -rf #{pkg_path}.expand
        pkgutil --expand /Volumes/#{identifier}/*.pkg #{pkg_path}.expand

        hdiutil detach '/Volumes/#{identifier}' || hdiutil detach '/Volumes/#{identifier}' -force

        # Adjust the install location (because no option exists during install)
        sed -i '' 's/<pkg-info/<pkg-info install-location="#{install_dir.gsub('/', '\\/')}"/' \\
               #{::File.join("#{pkg_path}.expand", 'PackageInfo')}

        # Then repack package
        pkgutil --flatten #{pkg_path}.expand #{pkg_path}
        EOF
      only_if { ::File.exist?(dmg_path) }
    end
  end
end
