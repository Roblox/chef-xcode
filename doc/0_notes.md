
## Notes

### Testing

When testing, ensure the VM has sufficient disk space for Xcode & simulators.

### Available Simulators

To see what simulators are available, below is an example Ruby script that can be used to get a list of URLs:
```ruby
require 'json'

xcode_info = '/Applications/Xcode.app/Contents/Info.plist'
xcode_version = `/usr/libexec/PlistBuddy -c "Print :DTXcode" #{xcode_info}`.chomp.to_i.to_s.split(//).join('.')
xcode_uuid = `/usr/libexec/PlistBuddy -c "Print :DVTPlugInCompatibilityUUID" #{xcode_info}`.chomp

if Gem::Version.new(xcode_version) >= Gem::Version.new('8.1')
  index_url = "https://devimages-cdn.apple.com/downloads/xcode/simulators/index-#{xcode_version}-#{xcode_uuid}.dvtdownloadableindex"
else
  index_url = "https://devimages.apple.com.edgekey.net/downloads/xcode/simulators/index-#{xcode_version}-#{xcode_uuid}.dvtdownloadableindex"
end

JSON.parse(`curl -Ls #{index_url} | plutil -convert json -o - -`)['downloadables'].map do |sim|
  sim_version_major = sim['version'].to_s.split('.')[0]
  sim_version_minor = sim['version'].to_s.split('.')[1]

  name = sim['name']
    .sub('$(DOWNLOADABLE_VERSION_MAJOR)', sim_version_major)
    .sub('$(DOWNLOADABLE_VERSION_MINOR)', sim_version_minor)

  identifier = sim['identifier']
    .sub('$(DOWNLOADABLE_VERSION_MAJOR)', sim_version_major)
    .sub('$(DOWNLOADABLE_VERSION_MINOR)', sim_version_minor)

  source = sim['source']
    .sub('$(DOWNLOADABLE_IDENTIFIER)', identifier)
    .sub('$(DOWNLOADABLE_VERSION)', sim['version'])

  puts "#{name} - SDK #{sim['version']} :"
  puts "    #{source}"
end
```
