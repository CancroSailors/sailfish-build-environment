#!/bin/sh

pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd`
popd > /dev/null

#Setup environment
ln -s $SCRIPTPATH/.hadk.env ~/.hadk.env
ln -s $SCRIPTPATH/.mersdk.profile ~/.mersdk.profile
ln -s $SCRIPTPATH/.mersdkubu.profile ~/.mersdkubu.profile

source ~/.hadk.env

mkdir -p $MER_TMPDIR
mkdir -p $ANDROID_ROOT/.repo/local_manifests
cp $SCRIPTPATH/cancro_local_manifest.xml $ANDROID_ROOT/.repo/local_manifests/cancro.xml

#Download Setup MER SDK
cd $MER_TMPDIR
TARBALL=mer-i486-latest-sdk-rolling-chroot-armv7hl-sb2.tar.bz2
curl -k -O https://img.merproject.org/images/mer-sdk/$TARBALL
mkdir -p $MER_ROOT/sdks/sdk
sudo tar --numeric-owner -p -xjf $MER_TMPDIR/$TARBALL
echo "export MER_ROOT=$MER_ROOT" >> ~/.bashrc
echo 'alias mersdk=$MER_ROOT/sdks/sdk/mer-sdk-chroot' >> ~/.bashrc
exec bash
echo 'PS1="MerSDK $PS1"' >> ~/.mersdk.profile
cd $HOME
mersdk
# These commands are a tmp workaround of glitch when working with target:
sudo zypper ar \
http://repo.merproject.org/obs/home:/sledge:/mer/latest_i486/ curlfix
sudo zypper ref curlfix
sudo zypper dup --from curlfix

echo "Mer SDK setup. You can start MerSDK by simply typing mersdk on your bash shell. Good Luck!"
