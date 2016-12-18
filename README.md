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
  3) fetch_sources: fetch android/mer sources
  4) setup_scratchbox: sets up a cross compilation toolchain to build mer packages
  5) test_scratchbox: tests the scratchbox toolchain.
  6) build_hybrishal: builds the hybris-hal needed to boot sailfishos for $DEVICE
  7) build_package PKG_PATH [spec files]: builds package at path specified by the spec files
  8) build_packages: builds packages needed to build the sailfishos rootfs of $DEVICE
  9) build_audioflingerglue: builds audioflingerglue packages for audio calls
  10) build_gstdroid: builds gstdroid for audio/video/camera support
  11) upload_packages: uploads droid-hal*, audioflingerglue, gstdroid* packages to OBS.
  12) generate_kickstart [obs]: generates a kickstart file needed to build rootfs. specifying obs will add the obs repo.
  13) build_rootfs [releasename]: builds a sailfishos installer zip for $DEVICE. Default release name is test.
  14) serve_repo : starts a http server in /path/to/droid-local-repo. (which you can "ssu ar http://<ipaddr>:8000" on device)
  15) update_sdk: Update the SDK target to the current stable version, if available.
  16) mer_man : show ths list of available functions
```

### More info:

* [Sailfish HADK](https://sailfishos.org/develop/hadk/)
* [Sailfish HADK FAQ](http://piratepad.net/hadk-faq-v2)

Thanks a ton to #saiflishos-porters on freenode
