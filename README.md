# sailfish-build-environment

A collection of scripts and functions to automate tasks while building Sailfish OS.

Review .hadk.env to make sure it suits your needs.

## Usage

`
  setup-mersdk.sh 
`

This script will Download and install mersdk and initialize it's environment with custom functions to automate tasks
So, Backup your ~/.hadk.env , ~/.mersdk.profile, ~/.mersdkubu.profile, if you already have any.

# sailfish-build-environment

A collection of scripts and functions to automate tasks while building Sailfish OS.

Review .hadk.env to make sure it suits your needs.

## Usage

```
  setup-mersdk.sh 
```

This script will Download and install mersdk and initialize it's environment with custom functions to automate tasks
So, Backup your ~/.hadk.env , ~/.mersdk.profile, ~/.mersdkubu.profile, if you already have any.

The Additional bash functions it provides are:

```
  1) setup_ubuntuchroot: set up ubuntu chroot for painless building of android
  2) setup_repo: sets up repo tool in ubuntu chroot to fetch android/mer sources
  3) setup_obsenv: sets up a folder to use OBS
  4) fetch_sources: fetch android/mer sources
  5) setup_scratchbox: sets up a cross compilation toolchain to build mer packages
  6) test_scratchbox: tests the scratchbox toolchain.
  7) build_hybrishal: builds the hybris-hal needed to boot sailfishos for $DEVICE
  8) build_package PKG_PATH [spec files]: builds package at path specified by the spec files
  9) build_packages: builds packages needed to build the sailfishos rootfs of $DEVICE
  10) build_audioflingerglue: builds audioflingerglue packages for audio calls
  11) build_gstdroid: builds gstdroid for audio/video/camera support
  12) upload_packages: uploads droid-hal*, audioflingerglue, gstdroid* packages to nemo:devel:hw:$VENDOR:$DEVICE on OBS
  13) promote_packages: promote packages on OBS from nemo:devel:hw:$VENDOR:$DEVICE to nemo:testing:hw:$VENDOR:$DEVICE
  14) generate_kickstart [local/release]: generates a kickstart file with devel repos, needed to build rootfs. Specifying local/release will switch the OBS repos
  15) build_rootfs [releasename]: builds a sailfishos installer zip for $DEVICE
  16) serve_repo : starts a http server on local host. (which you can easily add to your device as ssu ar http://<ipaddr>:9000)
  17) update_sdk: Update the SDK target to the current stable version, if available.
  18) mer_man: Show this help
```

### More info:

* [Sailfish HADK](https://sailfishos.org/develop/hadk/)
* [Sailfish HADK FAQ](http://piratepad.net/hadk-faq-v2)

Thanks a ton to #saiflishos-porters on freenode
