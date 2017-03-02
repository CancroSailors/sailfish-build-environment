#!/bin/sh

pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd`
popd > /dev/null

#Setup environment
rm ~/.hadk.env
rm ~/.mersdk.profile
rm ~/.mersdkubu.profile
ln -s $SCRIPTPATH/.hadk.env ~/.hadk.env
ln -s $SCRIPTPATH/.mersdk.profile ~/.mersdk.profile
ln -s $SCRIPTPATH/.mersdkubu.profile ~/.mersdkubu.profile

source ~/.hadk.env

mkdir -p $MER_TMPDIR
#mkdir -p $ANDROID_ROOT/.repo/local_manifests
cp $SCRIPTPATH/cancro_local_manifest.xml $ANDROID_ROOT/.repo/local_manifests/cancro.xml

#Download Setup MER SDK
cd $MER_TMPDIR
TARBALL=Jolla-latest-SailfishOS_Platform_SDK_Chroot-i486.tar.bz2 
curl -k -O -C - http://releases.sailfishos.org/sdk/installers/latest/$TARBALL

SDK_ROOT=$PLATFORM_SDK_ROOT/sdks/sfossdk
sudo rm -rf $SDK_ROOT
mkdir -p $SDK_ROOT
cd $SDK_ROOT
sudo tar --numeric-owner -p -xjf $MER_TMPDIR/$TARBALL

#Setup convenience bash aliases
echo "export PLATFORM_SDK_ROOT=$PLATFORM_SDK_ROOT" >> ~/.bashrc
echo "alias sfossdk=$SDK_ROOT/mer-sdk-chroot" >> ~/.bashrc

cd $HOME

sudo chroot $SDK_ROOT sudo zypper in -t pattern Mer-SB2-armv7hl

echo "SailfishOS Platform SDK setup complete. You can start Sailfish OS SDK by simply typing sfossdk on your bash shell. Good Luck!"
exec bash
