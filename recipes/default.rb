#
# Cookbook Name:: xcode
# Recipe:: default
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

# @TODO: Once updated to Chef 14, this is no longer needed.
include_recipe 'dmg'

=begin

Detailed example of what could be done in wrapper recipe

attributes/default.rb:

# Name of the data bag on the Server that contains the Xcode versions to install
default['xcode']['app']['data_bag'] = 'xcode_app_versions'

# Root folder where Xcode will be installed
default['xcode']['app']['install_root'] = nil

# Name of the data bag on the Server that contains the Simulators to install
default['xcode']['sim']['data_bag'] = 'xcode_sim_versions'

default['xcode']['last_gm_license'] = ''
default['xcode']['version_gm_license'] = ''

recipes/default.rb:

xcode_versions = data_bag(node['xcode']['app']['data_bag'])
default_xcode_version = nil

xcode_versions.each do |version|
  xcode = data_bag_item(node['xcode']['app']['data_bag'], version)

  xcode_app xcode['id'] do
    app xcode['app']
    url xcode['url']
    checksum xcode['checksum']
    force xcode['force'] || false
    install_suffix "v#{xcode['id']}"
    action xcode['action']
  end

  default_xcode_version = xcode['id'] if xcode['default']
end

simulator_versions = data_bag(node['xcode']['sim']['data_bag'])

simulator_versions.each do |version|
  simulator = data_bag_item(node['xcode']['sim']['data_bag'], version)

  xcode_simulator simulator['name'] do
    url simulator['url']
    checksum simulator['checksum']
    action simulator['action']
  end
end

link '/Applications/Xcode.app' do
  to "/Applications/Xcode_v#{default_xcode_version}.app"
  not_if { default_xcode_version.nil? }
end

ruby_block 'Set default Xcode' do
  block do
    execute 'xcode-select' do
      command "xcode-select -s /Applications/Xcode_v#{default_xcode_version}.app/Contents/Developer"
    end
  end
  not_if { default_xcode_version.nil? }
end

=end
