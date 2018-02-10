#!/bin/bash

FTP_HOST=$2
FTP_USER=$3
FTP_PSWD=$4

git fetch --unshallow
COUNT=$(git rev-list --count HEAD)
FILE=$COUNT-$5.7z

echo " "
echo "*** Trigger build ***"
echo " "
wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -q -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

chmod +x addons/sourcemod/scripting/spcomp

for file in SourcePawn/include/shop.inc
do
  sed -i "s%<commit-count>%$COUNT%g" $file > output.txt
  rm output.txt
done

mkdir build
mkdir build/plugins
mkdir build/scripts

cp -rf SourcePawn/* addons/sourcemod/scripting

addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/shop-core.sp -o"build/plugins/shop-core.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/shop-chat.sp -o"build/plugins/shop-chat.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/shop-skin.sp -o"build/plugins/shop-skin.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/shop-thirdperson.sp -o"build/plugins/shop-thirdperson.smx"

mv SQL build/scripts
mv SourcePawn/* build/scripts
mv LICENSE build

cd build
7z a $FILE -t7z -mx9 LICENSE plugins scripts >nul

echo -e "Upload file ..."
lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O /PuellaMagi/Shop/ $FILE"

echo "Upload RAW..."
cd plugins
lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O /PuellaMagi/Raw/ shop-core.smx"
lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O /PuellaMagi/Raw/ shop-chat.smx"
lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O /PuellaMagi/Raw/ shop-skin.smx"
lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O /PuellaMagi/Raw/ shop-thirdperson.smx"