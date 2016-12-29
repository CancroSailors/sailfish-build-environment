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

function setup_ubuntuchroot {
  mkdir -p $MER_TMPDIR
  pushd $MER_TMPDIR
  TARBALL=ubuntu-trusty-android-rootfs.tar.bz2
  curl -O http://img.merproject.org/images/mer-hybris/ubu/$TARBALL
  sudo rm -rf $HABUILD_ROOT
  sudo mkdir -p $HABUILD_ROOT
  sudo tar --numeric-owner -xvjf $TARBALL -C $HABUILD_ROOT
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

  SFE_SB2_TARGET=$MER_ROOT/targets/$VENDOR-$DEVICE-$PORT_ARCH
  TARBALL_URL=http://releases.sailfishos.org/sdk/latest/targets/targets.json
  TARBALL=$(curl $TARBALL_URL | grep "$PORT_ARCH.tar.bz2" | cut -d\" -f4 | grep $PORT_ARCH | head -n 1)

  echo "Downloading: " $TARBALL
  rm $(basename $TARBALL)
  curl -O $TARBALL

  sudo rm -rf $SFE_SB2_TARGET
  sudo mkdir -p $SFE_SB2_TARGET
  sudo tar --numeric-owner -pxjf $(basename $TARBALL) -C $SFE_SB2_TARGET

  sudo chown -R $USER $SFE_SB2_TARGET

  cd $SFE_SB2_TARGET
  grep :$(id -u): /etc/passwd >> etc/passwd
  grep :$(id -g): /etc/group >> etc/group

  sb2-init -d -L "--sysroot=/" -C "--sysroot=/" -c /usr/bin/qemu-arm-dynamic -m sdk-build -n -N -t / $VENDOR-$DEVICE-$PORT_ARCH /opt/cross/bin/$PORT_ARCH-meego-linux-gnueabi-gcc

  sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -m sdk-install -R rpm --rebuilddb
  sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -m sdk-install -R zypper ar -G http://repo.merproject.org/releases/mer-tools/rolling/builds/$PORT_ARCH/packages/ mer-tools-rolling
  sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -m sdk-install -R zypper ref --force

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
  PKG_PATH="$1"
  shift

  [ -z "$PKG_PATH" ] && echo "Please enter the path to the pkg source" && return

  pushd $PKG_PATH
  PKG="$(basename ${PWD})"

  if [ $? == "0" ]; then
    SPECS="$*"
    if [ -z "$SPECS" ]; then
      echo "No spec files for package building specified, building all I can find."
      SPECS="rpm/*.spec"
    fi

    for SPEC in $SPECS ; do
      echo "Building $SPEC"
      mb2 -s $SPEC -t $VENDOR-$DEVICE-$PORT_ARCH build || echo "Build failed" && return
    done

    echo "Building successful, adding packages to repo"
    mkdir -p "$ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG"
    rm -f "$ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG/"*.rpm
    mv RPMS/*.rpm "$ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG"
    createrepo "$ANDROID_ROOT/droid-local-repo/$DEVICE"
    sb2 -t $VENDOR-$DEVICE-$ARCH -R -msdk-install zypper ref
    echo "Building of $PKG finished successfully"
  fi
  popd
}

function build_packages {
  pushd $ANDROID_ROOT

  rpm/dhd/helpers/build_packages.sh $@

  popd
}

function build_audioflingerglue {
  ubu-chroot -r $HABUILD_ROOT /bin/bash -c "echo Building audioflingerglue && cd $ANDROID_ROOT && source build/envsetup.sh && breakfast $DEVICE && make -j8 libaudioflingerglue miniafservice"

  pushd $ANDROID_ROOT

  curl http://sprunge.us/OADK -o pack_source_af.sh
  curl http://sprunge.us/TEfZ -o audioflingerglue.spec

  chmod +x pack_source_af.sh
  ./pack_source_af.sh

  mb2 -s audioflingerglue.spec -t $VENDOR-$DEVICE-$PORT_ARCH build
  mv RPMS/*.rpm $ANDROID_ROOT/droid-local-repo/$DEVICE/
  createrepo $ANDROID_ROOT/droid-local-repo/$DEVICE
  sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -R -msdk-install zypper ref

  #Removing conflicting modules
  rm out/target/product/$DEVICE/system/bin/miniafservice
  rm out/target/product/$DEVICE/system/lib/libaudioflingerglue.so

  #Build pulseaudio-modules-droid-glue
  mkdir -p $MER_ROOT/devel/mer-hybris
  cd $MER_ROOT/devel/mer-hybris
  PKG=pulseaudio-modules-droid-glue
  rm -rf $PKG
  git clone https://github.com/mer-hybris/pulseaudio-modules-droid-glue.git
  cd $PKG
  curl http://pastebin.com/raw/H8U5nSNm -o pulseaudio-modules-droid-glue.patch
  patch -p1 < pulseaudio-modules-droid-glue.patch
    
  mb2 -s rpm/$PKG.spec -t $VENDOR-$DEVICE-$PORT_ARCH build
  mkdir -p $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG/
  rm -f $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG/*.rpm
  mv RPMS/*.rpm $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG
  createrepo $ANDROID_ROOT/droid-local-repo/$DEVICE
  sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -R -msdk-install zypper ref

  popd
}

function build_gstdroid {
  ubu-chroot -r $HABUILD_ROOT /bin/bash -c "echo Building gstdroid && cd $MER_ROOT/android/droid && source build/envsetup.sh && breakfast $DEVICE && make -j8 libcameraservice libdroidmedia minimediaservice minisfservice"
  pushd $ANDROID_ROOT

  curl http://sprunge.us/WPGA -o pack_source_droidmedia.sh
  curl http://sprunge.us/FWOg -o droidmedia.spec

  chmod +x pack_source_droidmedia.sh
  ./pack_source_droidmedia.sh
  mb2 -s droidmedia.spec -t $VENDOR-$DEVICE-$PORT_ARCH build
  mv RPMS/*.rpm $ANDROID_ROOT/droid-local-repo/$DEVICE/
  createrepo $ANDROID_ROOT/droid-local-repo/$DEVICE
  sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -R -msdk-install zypper ref

  rm out/target/product/$DEVICE/system/bin/minimediaservice
  rm out/target/product/$DEVICE/system/bin/minisfservice
  rm out/target/product/$DEVICE/system/lib/libdroidmedia.so

  mkdir -p $MER_ROOT/devel/mer-hybris
  cd $MER_ROOT/devel/mer-hybris
  PKG=gst-droid
  rm -rf $PKG
  git clone https://github.com/sailfishos/$PKG.git -b master
  cd $PKG

  mb2 -s rpm/$PKG.spec -t $VENDOR-$DEVICE-$PORT_ARCH build
  mkdir -p $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG/
  rm -f $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG/*.rpm
  mv RPMS/*.rpm $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG
  createrepo $ANDROID_ROOT/droid-local-repo/$DEVICE
  sb2 -t $VENDOR-$DEVICE-$PORT_ARCH -R -msdk-install zypper ref

  popd
}

function generate_kickstart {
  pushd $ANDROID_ROOT


  hybris/droid-configs/droid-configs-device/helpers/process_patterns.sh

  mkdir -p tmp
  KS="Jolla-@RELEASE@-$DEVICE-@ARCH@.ks"

  cp $ANDROID_ROOT/hybris/droid-configs/installroot/usr/share/kickstarts/$KS $ANDROID_ROOT/tmp/$KS

  #By default we have a kickstart file which points to devel repos. Using this switch we can switch to local/testing repos
  if [ $1 == "local" ]; then
    HA_REPO="repo --name=adaptation-community-$DEVICE-@RELEASE@"
    sed -i -e "s|^$HA_REPO.*$|$HA_REPO --baseurl=file://$ANDROID_ROOT/droid-local-repo/$DEVICE|" $ANDROID_ROOT/tmp/$KS
  elif [ $1 == "release" ]; then
    #Adding our OBS repo
    sed -i -e "s/nemo\:\/devel/nemo\:\/testing/g" $ANDROID_ROOT/tmp/$KS
    sed -i -e "s/sailfish_latest_@ARCH@\//sailfishos_@RELEASE@\//g" $ANDROID_ROOT/tmp/$KS
  fi

  sed -i -e "s|@Jolla Configuration $DEVICE|@Jolla Configuration $DEVICE\njolla-email\nsailfish-weather\njolla-calculator\njolla-notes\njolla-calendar\nsailfish-office|"  $ANDROID_ROOT/tmp/$KS

  #Hacky workaround for droid-hal-init starting before /system partition is mounted
  #sed -i '/%post$/a sed -i \"s;WantedBy;RequiredBy;g\"  \/lib\/systemd\/system\/system.mount' $ANDROID_ROOT/tmp/$KS
  #sed -i '/%post$/a echo \"RequiredBy=droid-hal-init.service\" >> \/lib\/systemd\/system\/local-fs.target' $ANDROID_ROOT/tmp/$KS
  #sed -i '/%post$/a echo \"[Install]\" >> \/lib\/systemd\/system\/local-fs.target' $ANDROID_ROOT/tmp/$KS

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
  cp $ANDROID_ROOT/droid-local-repo/$DEVICE/audioflingerglue* .
  cp $ANDROID_ROOT/droid-local-repo/$DEVICE/droidmedia* .
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
