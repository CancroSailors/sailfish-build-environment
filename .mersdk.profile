function hadk() { source $HOME/.hadk.env; echo "Env setup for $DEVICE"; }
hadk

alias enter_habuildsdk="ubu-chroot -r $HABUILD_ROOT"
alias enter_scratchbox="sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -m sdk-install -R"

PS1="MerSDK $PS1"

#TODO add error checks

pushd () {
  command pushd "$@" > /dev/null
}

popd () {
  command popd "$@" > /dev/null
}

die () {
  if [ -z "$*" ]; then
    echo "command failed at `date`, dying..."
  else
    echo "$*"
  fi
  exit 1
}


function setup_ubuntuchroot {
  mkdir -p $MER_TMPDIR
  pushd $MER_TMPDIR
  TARBALL=ubuntu-trusty-android-rootfs.tar.bz2
  curl -k -O -C - http://img.merproject.org/images/mer-hybris/ubu/$TARBALL || die "Error downloading ubuntu rootfs"
  sudo rm -rf $HABUILD_ROOT
  sudo mkdir -p $HABUILD_ROOT
  sudo tar --numeric-owner -xvjf $TARBALL -C $HABUILD_ROOT
  ubu-chroot -r $HABUILD_ROOT /bin/bash -c "echo Installing useful tools && sudo apt-get update && sudo apt-get install -y rsync vim unzip silversearcher-ag bsdmainutils openjdk-7-jdk && sudo update-java-alternatives -s java-1.7.0-openjdk-amd64"
  popd
}

function setup_repo {
  mkdir -p $ANDROID_ROOT
  sudo chown -R $USER $ANDROID_ROOT
  ubu-chroot -r $HABUILD_ROOT /bin/bash -c "echo Installing repo && curl -O https://storage.googleapis.com/git-repo-downloads/repo && chmod a+x repo && sudo mv repo /usr/bin"
}

function fetch_sources {
  ubu-chroot -r $HABUILD_ROOT /bin/bash -c "echo Initializing repo && cd $ANDROID_ROOT && repo init -u git://github.com/mer-hybris/android.git -b $HYBRIS_BRANCH"
  ubu-chroot -r $HABUILD_ROOT /bin/bash -c "echo Syncing sources && cd $ANDROID_ROOT && repo sync --fetch-submodules"
}

function setup_scratchbox {
  mkdir -p $MER_TMPDIR
  pushd $MER_TMPDIR

  sdk-assistant create SailfishOS-latest http://releases.sailfishos.org/sdk/latest/Jolla-latest-Sailfish_SDK_Tooling-i486.tar.bz2
  sdk-assistant create $VENDOR-$DEVICE-$PORT_$ARCH http://releases.sailfishos.org/sdk/latest/Jolla-latest-Sailfish_SDK_Target-armv7hl.tar.bz2

  popd
}

function test_scratchbox {
  mkdir -p $MER_TMPDIR
  pushd $MER_TMPDIR

  cat > main.c << EOF
#include <stdlib.h>
#include <stdio.h>
int main(void) {
printf("Scratchbox, works!\n");
return EXIT_SUCCESS;
}
EOF

  sb2 -t $VENDOR-$DEVICE-$PORT_ARCH gcc main.c -o test
  sb2 -t $VENDOR-$DEVICE-$PORT_ARCH ./test

  popd
}

function build_hybrishal {
  ubu-chroot -r $HABUILD_ROOT /bin/bash -c "echo Building hybris-hal && cd $ANDROID_ROOT && source build/envsetup.sh && breakfast $DEVICE && make -j8 hybris-hal"
}

function build_package {
  PKG_PATH=`readlink -e $1`
  shift
  pushd $PKG_PATH
  SPECS=$1
  if [ -z "$SPECS" ]; then
    echo "No spec file for package building specified, building all I can find."
    SPECS="rpm/*.spec"
  fi
  for SPEC in $SPECS ; do
    minfo "Building $SPEC"
    mb2 -s $SPEC -t $VENDOR-$DEVICE-$PORT_ARCH build || die "Error building package $1"
  done

  PKG=`basename $PKG_PATH`
  mkdir -p "$ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG"
  rm -f "$ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG/"*.rpm
  mv RPMS/*.rpm "$ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG"
  echo "Packages Built:"
  ls $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG/
  popd
}

function build_packages {
  pushd $ANDROID_ROOT

  rpm/dhd/helpers/build_packages.sh $@
  rpm/dhd/helpers/build_packages.sh --mw="https://git.merproject.org/kimmoli/pulseaudio-policy-enforcement.git"
  rpm/dhd/helpers/build_packages.sh --mw="https://git.merproject.org/mer-core/qt-mobility-haptics-ffmemless.git"

  popd
}

function fetch_mw {
  mkdir -p $HYBRIS_MW_ROOT
  pushd $HYBRIS_MW_ROOT

  PKG=`basename $1 .git`
  if [ -d "$PWD/$PKG" ]
  then
    cd $PWD/$PKG
    git pull
    git submodule update
  else
    git clone $1
    cd $PWD/$PKG
    git submodule init
    git submodule update
  fi
  popd
}

function build_audioflingerglue {
  ubu-chroot -r $HABUILD_ROOT /bin/bash -c "echo Building audioflingerglue && cd $ANDROID_ROOT && source build/envsetup.sh && breakfast $DEVICE && make -j8 libaudioflingerglue miniafservice"

  pushd $ANDROID_ROOT

  PKG_PATH=$HYBRIS_MW_ROOT/audioflingerglue-localbuild
  mkdir -p $PKG_PATH/rpm

  #FIXME: DO NOT hardcode the version of the tgz archive of audioflingerglue
  $ANDROID_ROOT/rpm/dhd/helpers/pack_source_audioflingerglue-localbuild.sh
  mv $HYBRIS_MW_ROOT/audioflingerglue-0.0.1.tgz $PKG_PATH/
  cp $ANDROID_ROOT/rpm/dhd/helpers/audioflingerglue-localbuild.spec $PKG_PATH/rpm/audioflingerglue.spec
  build_package $PKG_PATH

  #Build pulseaudio-modules-droid-glue
  PKG_REPO=https://github.com/mer-hybris/pulseaudio-modules-droid-glue.git
  PKG=`basename $PKG_REPO .git`

  fetch_mw $PKG_REPO || die "Unable to fetch $PKG_REPO"
  #pushd $HYBRIS_MW_ROOT/$PKG
  #curl http://pastebin.com/raw/H8U5nSNm -o pulseaudio-modules-droid-glue.patch
  #patch -p1 < pulseaudio-modules-droid-glue.patch
  #popd

  build_package $HYBRIS_MW_ROOT/$PKG

  popd
}

function build_gstdroid {
  ubu-chroot -r $HABUILD_ROOT /bin/bash -c "echo Building gstdroid && cd $MER_ROOT/android/droid && source build/envsetup.sh && breakfast $DEVICE && make -j8 libcameraservice libdroidmedia minimediaservice minisfservice"
  pushd $ANDROID_ROOT

  PKG_PATH=$HYBRIS_MW_ROOT/droidmedia-localbuild
  mkdir -p $PKG_PATH/rpm/

  DROIDMEDIA_VERSION=$(git --git-dir $ANDROID_ROOT/external/droidmedia/.git describe --tags | sed -r "s/\-/\+/g")
  sed -e "s/0.0.0/$DROIDMEDIA_VERSION/" $ANDROID_ROOT/rpm/dhd/helpers/droidmedia-localbuild.spec > $PKG_PATH/rpm/droidmedia.spec

  #FIXME: Do not hardcode version this way
  $ANDROID_ROOT/rpm/dhd/helpers/pack_source_droidmedia-localbuild.sh $DROIDMEDIA_VERSION
  mv $HYBRIS_MW_ROOT/droidmedia-$DROIDMEDIA_VERSION.tgz $PKG_PATH/
  build_package $PKG_PATH

  PKG_REPO=https://github.com/sailfishos/gst-droid.git
  fetch_mw $PKG_REPO
  build_package $ANDROID_ROOT/hybris/mw/`basename $PKG_REPO .git`

  popd
}

function generate_kickstart {
  pushd $ANDROID_ROOT

  hybris/droid-configs/droid-configs-device/helpers/process_patterns.sh

  mkdir -p tmp
  KS="Jolla-@RELEASE@-$DEVICE-@ARCH@.ks"
  KS_PATH=$ANDROID_ROOT/tmp/$KS

  cp $ANDROID_ROOT/hybris/droid-configs/installroot/usr/share/kickstarts/$KS $KS_PATH

  #By default we make the kickstart file point to devel repos.
  HA_REPO="repo --name=adaptation-community-$DEVICE-@RELEASE@"
  HA_REPO_COMMON="repo --name=adaptation-community-common-$DEVICE-@RELEASE@"
  if ! grep -q "$HA_REPO" $KS_PATH; then
    echo "Adding devel repo to the kick start"
    sed -i -e "s|^$HA_REPO_COMMON|$HA_REPO --baseurl=http://repo.merproject.org/obs/nemo:/devel:/hw:/$VENDOR:/$DEVICE/sailfish_latest_@ARCH@/\n$HA_REPO_COMMON|" $KS_PATH
  fi

  #Using this switch we can switch to local/testing repos
  if [[ "$#" -eq 1 && $1 == "local" ]]; then
    sed -i -e "s|^$HA_REPO.*$|$HA_REPO --baseurl=file://$ANDROID_ROOT/droid-local-repo/$DEVICE|" $KS_PATH
  elif [[ "$#" -eq 1  && $1 == "release" ]]; then
    #Adding our OBS repo
    sed -i -e "s/nemo\:\/devel/nemo\:\/testing/g" $KS_PATH
    sed -i -e "s/sailfish_latest_@ARCH@\//sailfishos_@RELEASE@\//g" $KS_PATH
  fi

  sed -i -e "s|@Jolla Configuration $DEVICE|@Jolla Configuration $DEVICE\njolla-email\nsailfish-weather\njolla-calculator\njolla-notes\njolla-calendar\nsailfish-office\nharbour-poor-maps|"  $KS_PATH

  #Hacky workaround for droid-hal-init starting before /system partition is mounted
  #sed -i '/%post$/a sed -i \"s;WantedBy;RequiredBy;g\"  \/lib\/systemd\/system\/system.mount' $KS_PATH
  #sed -i '/%post$/a echo \"RequiredBy=droid-hal-init.service\" >> \/lib\/systemd\/system\/local-fs.target' $KS_PATH
  #sed -i '/%post$/a echo \"[Install]\" >> \/lib\/systemd\/system\/local-fs.target' $KS_PATH

  popd
}

function build_rootfs {
  RELEASE=$SAILFISH_VERSION
  if [[ -z "$1" ]]
  then
    EXTRA_NAME=-test
  else
    EXTRA_NAME=-$1
  fi
  echo Building Image: $EXTRA_NAME
  sudo mic create fs --arch $PORT_ARCH --debug --tokenmap=ARCH:$PORT_ARCH,RELEASE:$RELEASE,EXTRA_NAME:$EXTRA_NAME --record-pkgs=name,url --outdir=sfe-$DEVICE-$RELEASE$EXTRA_NAME --pack-to=sfe-$DEVICE-$RELEASE$EXTRA_NAME.tar.bz2 $ANDROID_ROOT/tmp/Jolla-@RELEASE@-$DEVICE-@ARCH@.ks
}

function serve_repo {
  LOCAL_ADDRESSES=$(/sbin/ip addr | grep inet | grep -v inet6 | grep -v "host lo" | cut -f6 -d' ' | cut -f 1 -d'/')
  LOCAL_PORT=2016
  echo "Starting a repo on this machine. You can add it to your device using:"
  for ADDR in $LOCAL_ADDRESSES; do echo "   " ssu ar local http://$ADDR:$LOCAL_PORT/; done

  pushd $ANDROID_ROOT/droid-local-repo/$DEVICE/
  python -m SimpleHTTPServer $LOCAL_PORT
  popd
}

function update_sdk {
  SFE_SB2_TARGET=$MER_ROOT/targets/$VENDOR-$DEVICE-$PORT_ARCH
  TARGETS_URL=http://releases.sailfishos.org/sdk/latest/targets/targets.json
  CURRENT_STABLE_TARGET=$(curl -s $TARGETS_URL 2>/dev/null | grep "$PORT_ARCH.tar.bz2" | cut -d\" -f4 | grep $PORT_ARCH | head -n 1)
  CURRENT_STABLE_VERSION=`echo $CURRENT_STABLE_TARGET | cut -d'/' -f6 | cut -f 2 -d'-'`

  if [ "$CURRENT_STABLE_VERSION" == "$SAILFISH_VERSION" ]
  then
    echo "You are already at the latest Release:" $SAILFISH_VERSION
  else
    echo "There is an updated version available:" $CURRENT_STABLE_VERSION
    read -p "Are you sure you wish to update? [Y/n]" -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]
    then
      sed -i /export\ SAILFISH_VERSION/s/.*/export\ SAILFISH_VERSION=$CURRENT_STABLE_VERSION/ ~/.hadk.env
      . ~/.hadk.env
      echo Updating to $SAILFISH_VERSION
      sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -R -msdk-install ssu re $SAILFISH_VERSION
      sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -R -msdk-install zypper ref
      sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -R -msdk-install zypper dup
      sudo zypper ref
      sudo zypper dup
      sudo ssu re $SAILFISH_VERSION
      sudo zypper ref
      sudo zypper dup
    fi
  fi
}

function setup_obsenv {
  if [[ ! -d $OBS_ROOT ]] 
  then
     sudo mkdir $OBS_ROOT
     sudo chown $USER $OBS_ROOT
     echo ""
     echo " Make yourself familier with setting up .oscrc"
     echo " https://wiki.merproject.org/wiki/Building_against_Mer_in_Community_OBS#Setup_.oscrc"
     echo ""
  fi
}

function upload_packages {
  #Upload gstdroid and droid-hal* to OBS
  pushd $OBS_ROOT/nemo\:devel\:hw\:$VENDOR\:$DEVICE/droid-hal-$DEVICE/

  osc up
  rm *.rpm
  cp $ANDROID_ROOT/droid-local-repo/$DEVICE/droid-hal-$DEVICE/* .
  cp $ANDROID_ROOT/droid-local-repo/$DEVICE/audioflingerglue-localbuild/* .
  cp $ANDROID_ROOT/droid-local-repo/$DEVICE/droidmedia-localbuild/* .
  osc ar
  osc ci

  popd
}

function promote_packages {
  #Promote packages from devel repo to testing repo
  TESTING_REPO="nemo:testing:hw:$VENDOR:$DEVICE"
  DEVEL_REPO="nemo:devel:hw:$VENDOR:$DEVICE"

  #Ignoring the _pattern package and comments.
  #Wrapping each package name with % %, for easier array search
  DEVEL_PACKAGES=`osc ls $DEVEL_REPO | grep -v "_pattern\|^#" | sed -e 's/^/%/' | sed -e 's/$/%/'`
  TESTING_PACKAGES=`osc ls $TESTING_REPO | grep -v "_pattern\|^#" | sed -e 's/^/%/' | sed -e 's/$/%/'`

  # Delete any packages which are in testing repo but not in devel
  for PACKAGE in $TESTING_PACKAGES; do
    if [[ ! "${DEVEL_PACKAGES[@]}" =~ "${PACKAGE}" ]]; then
      osc -A https://api.merproject.org rdelete $TESTING_REPO ${PACKAGE//%/} -m maintenance
    fi
  done

  # Copy packages over from devel to testing
  for PACKAGE in $DEVEL_PACKAGES; do
    osc -A https://api.merproject.org copypac $DEVEL_REPO ${PACKAGE//%/} $TESTING_REPO
  done
}

function mer_man {
  echo "Welcome to MerSDK"
  echo "Additional convenience functions defined here are:"
  echo "  1) setup_ubuntuchroot: set up ubuntu chroot for painless building of android"
  echo "  2) setup_repo: sets up repo tool in ubuntu chroot to fetch android/mer sources"
  echo "  3) setup_obsenv: sets up a folder to use OBS"
  echo "  4) fetch_sources: fetch android/mer sources"
  echo "  5) setup_scratchbox: sets up a cross compilation toolchain to build mer packages"
  echo "  6) test_scratchbox: tests the scratchbox toolchain."
  echo "  7) build_hybrishal: builds the hybris-hal needed to boot sailfishos for $DEVICE"
  echo "  8) build_package PKG_PATH [spec files]: builds package at path specified by the spec files"
  echo "  9) build_packages: builds packages needed to build the sailfishos rootfs of $DEVICE"
  echo "  10) build_audioflingerglue: builds audioflingerglue packages for audio calls"
  echo "  11) build_gstdroid: builds gstdroid for audio/video/camera support"
  echo "  12) upload_packages: uploads droid-hal*, audioflingerglue, gstdroid* packages to nemo:devel:hw:$VENDOR:$DEVICE on OBS"
  echo "  13) promote_packages: promote packages on OBS from nemo:devel:hw:$VENDOR:$DEVICE to nemo:testing:hw:$VENDOR:$DEVICE"
  echo "  14) generate_kickstart [local/release]: generates a kickstart file with devel repos, needed to build rootfs. Specifying local/release will switch the OBS repos"
  echo "  15) build_rootfs [releasename]: builds a sailfishos installer zip for $DEVICE"
  echo "  16) serve_repo : starts a http server on local host. (which you can easily add to your device as ssu ar http://<ipaddr>:9000)"
  echo "  17) update_sdk: Update the SDK target to the current stable version, if available."
  echo "  18) mer_man: Show this help"
}

cd $ANDROID_ROOT
mer_man
