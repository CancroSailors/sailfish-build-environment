function hadk() { source $HOME/.hadk.env; echo "Env setup for $DEVICE"; }
hadk
alias mersdkubu="ubu-chroot -r $MER_ROOT/sdks/ubuntu"
PS1="MerSDK $PS1"

function setup_ubuntuchroot {
  TARBALL=ubuntu-trusty-android-rootfs.tar.bz2
  curl -O http://img.merproject.org/images/mer-hybris/ubu/$TARBALL
  UBUNTU_CHROOT=$MER_ROOT/sdks/ubuntu
  sudo rm -rf $UBUNTU_CHROOT
  sudo mkdir -p $UBUNTU_CHROOT
  sudo tar --numeric-owner -xvjf $TARBALL -C $UBUNTU_CHROOT
}

function setup_repo {
  mkdir -p $ANDROID_ROOT
  sudo chown -R $USER $ANDROID_ROOT
  ubu-chroot -r $MER_ROOT/sdks/ubuntu /bin/bash -c "echo Installing repo && curl -O https://storage.googleapis.com/git-repo-downloads/repo && chmod a+x repo && sudo mv repo /usr/bin"
}

function fetch_sources {
  cd $ANDROID_ROOT

  ubu-chroot -r $MER_ROOT/sdks/ubuntu /bin/bash -c "echo Initializing repo && cd $ANDROID_ROOT && repo init -u git://github.com/mer-hybris/android.git -b $HYBRIS_BRANCH"
  ubu-chroot -r $MER_ROOT/sdks/ubuntu /bin/bash -c "echo Syncing sources && cd $ANDROID_ROOT && repo sync --fetch-submodules"
}

function setup_scratchbox {
  mkdir -p $MER_TMPDIR
  cd $MER_TMPDIR

  SFE_SB2_TARGET=$MER_ROOT/targets/$VENDOR-$DEVICE-$PORT_ARCH
  TARBALL_URL=http://releases.sailfishos.org/sdk/latest/targets/targets.json
  TARBALL=$(curl $TARBALL_URL | grep "$PORT_ARCH.tar.bz2" | cut -d\" -f4)

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
}

function test_scratchbox {
  mkdir -p $MER_TMPDIR
  cd $MER_TMPDIR

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
}

function build_hybrishal {
  cd $ANDROID_ROOT
  ubu-chroot -r $MER_ROOT/sdks/ubuntu /bin/bash -c "echo Building hybris-hal && cd $ANDROID_ROOT && source build/envsetup.sh && breakfast $DEVICE && make -j8 hybris-hal"
}

function build_packages {
  cd $ANDROID_ROOT
  rpm/dhd/helpers/build_packages.sh
}

function build_audioflingerglue {
  ubu-chroot -r $MER_ROOT/sdks/ubuntu /bin/bash -c "echo Building audioflingerglue && cd $ANDROID_ROOT && source build/envsetup.sh && breakfast $DEVICE && make -j8 libaudioflingerglue miniafservice"

  cd $ANDROID_ROOT

  curl http://sprunge.us/OADK -o pack_source_af.sh
  curl http://sprunge.us/TEfZ -o audioflingerglue.spec

  chmod +x pack_source_af.sh
  ./pack_source_af.sh

  mb2 -s audioflingerglue.spec -t $VENDOR-$DEVICE-armv7hl build
  mv RPMS/*.rpm $ANDROID_ROOT/droid-local-repo/$DEVICE/
  createrepo $ANDROID_ROOT/droid-local-repo/$DEVICE
  sb2 -t $VENDOR-$DEVICE-armv7hl -R -msdk-install zypper ref 

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
    
  mb2 -s rpm/$PKG.spec -t $VENDOR-$DEVICE-armv7hl build
  mkdir -p $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG/
  rm -f $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG/*.rpm
  mv RPMS/*.rpm $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG
  createrepo $ANDROID_ROOT/droid-local-repo/$DEVICE
  sb2 -t $VENDOR-$DEVICE-armv7hl -R -msdk-install zypper ref
}

function build_gstdroid {
  ubu-chroot -r $MER_ROOT/sdks/ubuntu /bin/bash -c "echo Building gstdroid && cd $MER_ROOT/android/droid && source build/envsetup.sh && breakfast $DEVICE && make -j8 libcameraservice libdroidmedia minimediaservice minisfservice"
  cd $ANDROID_ROOT

  curl http://sprunge.us/WPGA -o pack_source_droidmedia.sh
  cd $ANDROID_ROOT
  chmod +x pack_source_droidmedia.sh
  ./pack_source_droidmedia.sh
  mb2 -s droidmedia.spec -t $VENDOR-$DEVICE-armv7hl build
  mv RPMS/*.rpm $ANDROID_ROOT/droid-local-repo/$DEVICE/
  createrepo $ANDROID_ROOT/droid-local-repo/$DEVICE
  sb2 -t $VENDOR-$DEVICE-armv7hl -R -msdk-install zypper ref

  rm out/target/product/$DEVICE/system/bin/minimediaservice
  rm out/target/product/$DEVICE/system/bin/minisfservice
  rm out/target/product/$DEVICE/system/lib/libdroidmedia.so

  mkdir -p $MER_ROOT/devel/mer-hybris
  cd $MER_ROOT/devel/mer-hybris
  PKG=gst-droid
  rm -rf $PKG
  git clone https://github.com/sailfishos/$PKG.git -b master
  cd $PKG

  mb2 -s rpm/$PKG.spec -t $VENDOR-$DEVICE-armv7hl build
  mkdir -p $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG/
  rm -f $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG/*.rpm
  mv RPMS/*.rpm $ANDROID_ROOT/droid-local-repo/$DEVICE/$PKG
  createrepo $ANDROID_ROOT/droid-local-repo/$DEVICE
  sb2 -t $VENDOR-$DEVICE-armv7hl -R -msdk-install zypper ref
}

function generate_kickstart {
  cd $ANDROID_ROOT
  mkdir -p tmp
  HA_REPO="repo --name=adaptation0-$DEVICE-@RELEASE@"
  KS="Jolla-@RELEASE@-$DEVICE-@ARCH@.ks"
  #Older version
  #sed -e "s|^$HA_REPO.*$|$HA_REPO --baseurl=file://$ANDROID_ROOT/droid-local-repo/$DEVICE|" $ANDROID_ROOT/hybris/droid-configs/installroot/usr/share/kickstarts/$KS > $ANDROID_ROOT/tmp/$KS
  sed -e "s|^$HA_REPO.*$|$HA_REPO --baseurl=file://$ANDROID_ROOT/droid-local-repo/$DEVICE|;s|^repo --name=jolla-@RELEASE@.*|& \nrepo --name=common --baseurl=http://repo.merproject.org/obs/nemo:/testing:/hw:/common/sailfish_latest_armv7hl\nrepo --name=openrepos-basil --baseurl=https://sailfish.openrepos.net/basil/personal/main/|" \
$ANDROID_ROOT/hybris/droid-configs/installroot/usr/share/kickstarts/$KS > $ANDROID_ROOT/tmp/$KS

  hybris/droid-configs/droid-configs-device/helpers/process_patterns.sh


  if [ $1 = "obs" ]; then
    #Adding our OBS repo
    MOBS_URI="http://repo.merproject.org/obs"
    HA_REPO="repo --name=adaptation0-$DEVICE-@RELEASE@"
    HA_REPO1="repo --name=adaptation1-$DEVICE-@RELEASE@ --baseurl=$MOBS_URI/nemo:/devel:/hw:/$VENDOR:/$DEVICE/sailfish_latest_@ARCH@/"
    sed -i -e "/^$HA_REPO.*$/a$HA_REPO1" $ANDROID_ROOT/tmp/$KS
  fi

    sed -i -e "s|@Jolla Configuration cancro|@Jolla Configuration cancro\njolla-email\nsailfish-weather\njolla-calculator\njolla-notes\njolla-calendar\nsailfish-office\nharbour-warehouse|"  $ANDROID_ROOT/tmp/$KS
}

function upload_packages {
  #Upload gstdroid and droid-hal* to OBS
  cd $MER_ROOT/OBS/nemo\:devel\:hw\:$VENDOR\:$DEVICE/droid-hal-$DEVICE/
  osc up
  rm *.rpm
  cp $ANDROID_ROOT/droid-local-repo/$DEVICE/droid-hal-$DEVICE* .
  cp $ANDROID_ROOT/droid-local-repo/$DEVICE/audioflingerglue* .
  cp $ANDROID_ROOT/droid-local-repo/$DEVICE/droidmedia* .
  osc ar
  osc ci  
}

function build_rootfs {
  RELEASE=2.0.2.51
  if [[ -z "$1" ]]
  then
    EXTRA_NAME=-test
  else
    EXTRA_NAME=-$1
  fi
  echo Building Image: $EXTRA_NAME
  sudo mic create fs --arch $PORT_ARCH --debug --tokenmap=ARCH:$PORT_ARCH,RELEASE:$RELEASE,EXTRA_NAME:$EXTRA_NAME --record-pkgs=name,url --outdir=sfe-$DEVICE-$RELEASE$EXTRA_NAME --pack-to=sfe-$DEVICE-$RELEASE$EXTRA_NAME.tar.bz2 $ANDROID_ROOT/tmp/Jolla-@RELEASE@-$DEVICE-@ARCH@.ks
}


function mer_man {
  echo "Welcome to MerSDK"
  echo "Additional convenience functions defined here are:"
  echo "  1) setup_ubuntuchroot: set up ubuntu chroot for painless building of android"
  echo "  2) setup_repo: sets up repo tool in ubuntu chroot to fetch android/mer sources"
  echo "  3) fetch_sources: fetch android/mer sources"
  echo "  4) setup_scratchbox: sets up a cross compilation toolchain to build mer packages"
  echo "  5) test_scratchbox: tests the scratchbox toolchain."
  echo "  6) build_hybrishal: builds the hybris-hal needed to boot sailfishos for $DEVICE"
  echo "  7) build_packages: builds packages needed to build the sailfishos rootfs of $DEVICE"
  echo "  8) build_audioflingerglue: builds audioflingerglue packages for audio calls"
  echo "  9) build_gstdroid: builds gstdroid for audio/video/camera support"
  echo "  9) upload_packages: uploads droid-hal*, audioflingerglue, gstdroid* packages to OBS"
  echo "  10) generate_kickstart [obs]: generates a kickstart file needed to build rootfs. specifying obs will add the obs repo"
  echo "  11) build_rootfs [releasename]: builds a sailfishos installer zip for $DEVICE"
  echo "  12) mer_man: Show this help"
}

mer_man
