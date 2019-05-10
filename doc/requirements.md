
Xcode Command Line Tools should already be installed either by `brew` or through [build-essential](https://supermarket.chef.io/cookbooks/build-essential).

## Limitations

This does not yet support Xcode packaged with XIP. It is recommended to download and convert to DMG.

The DMGs are not accessible from Apple directly without logging into the developer center,
you must place the DMGs on your own fileserver and list them in a data bag on your Chef server.
