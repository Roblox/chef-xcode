The cookbook provides a resource to install Xcode with the options (default) to install multiple versions, side by side.
This side-by-side installation is especially useful for those that run build farms and need to support multiple Xcode versions.

Installs Xcode on Lion, Mountain Lion, Mavericks, Yosemite, El Capitan, Sierra, High Sierra, and Mojava.

Include `xcode` cookbook in recipe or the node's `run_list` to esnure the `dmg` cookbook is included:
```ruby
include_recipe 'xcode'
```
Or
```json
{
  "name":"my_node",
  "run_list": [
    "recipe[xcode]"
  ]
}
```
