#!/bin/bash

##########################################################
##                                                      ##
## Shell script for generating a boards manager release ##
## Created by MCUdude                                   ##
## Requires wget, jq and a bash environment             ##
## Modified by Bernhard Nebel                           ##
##                                                      ##
## Usage: ./Boards_manager_release.sh repo              ##
##                                                      ##
##########################################################
# Change these to match your repo
REPO=$1                 # Github repo
OWNER=felias-fogg       # Github username
VERSION=$(curl -s https://api.github.com/repos/$OWNER/$REPO/releases/latest | grep "tag_name" |  awk -F\" '{print $4}')
if [ -z "$VERSION" ]; then
    echo "Could not find repo '$REPO'"
    exit 1
fi
VNUM=${VERSION#"v"}
PAOVERSION=$(curl -s https://api.github.com/repos/$OWNER/PyAvrOCD/releases/latest | grep "tag_name" |  awk -F\" '{print $4}')
PAONUM=${PAOVERSION#"v"}

# Get the download URL for the latest release from Github
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/$OWNER/$REPO/releases/latest | grep "tarball_url" | awk -F\" '{print $4}')

# Download file
wget --no-verbose $DOWNLOAD_URL

# Get filename
DOWNLOADED_FILE=$(echo $DOWNLOAD_URL | awk -F/ '{print $8}')

# Add .tar.bz2 extension to downloaded file
mv $DOWNLOADED_FILE ${DOWNLOADED_FILE}.tar.bz2

# Extract downloaded file and place it in a folder
printf "\nExtracting folder ${DOWNLOADED_FILE}.tar.bz2 to $REPO-$VNUM\n"
mkdir -p "$REPO-$VNUM" && tar -xzf ${DOWNLOADED_FILE}.tar.bz2 -C "$REPO-$VNUM" --strip-components=1
printf "Done!\n"

# Move files out of the avr folder (if present)
if [ -d $REPO-$VNUM/avr ]; then
    mv $REPO-$VNUM/avr/* $REPO-$VNUM
    rm -rf $REPO-$VNUM/avr
fi

# Delete downloaded file
rm -rf ${DOWNLOADED_FILE}.tar.bz2

# Check whether version numbers match
PLATFORM=$(grep -E "version=\d+\.\d+\.\d+" $REPO-$VNUM/platform.txt)
PNUM=${PLATFORM#version=}

if [ "x$PNUM" != "x$VNUM" ]; then
    echo "Version numbers do not match"
    exit 1
fi

PRESENT=`jq --arg file $REPO-$VNUM.tar.bz2 '[.packages[].platforms[].archiveFileName | . == $file] | any' "package_debugging_index.json"`
if [ "true" == "$PRESENT" ]; then
    echo "Version is already present in index!"
    rm -rf $REPO-$VNUM
    exit 1
fi

# extract name from platform.txt
NAMELINE=$(grep "^name=" $REPO-$VNUM/platform.txt)
NICENAME=${NAMELINE#name=}

dot_clean .

# Compress folder to tar.bz2
printf "\nCompressing folder $REPO-$VNUM to $REPO-$VNUM.tar.bz2\n"
tar -cjSf $REPO-$VNUM.tar.bz2 $REPO-$VNUM
printf "Done!\n"

# Get file size on bytes
FILE_SIZE=$(wc -c "$REPO-$VNUM.tar.bz2" | awk '{print $1}')

# Get SHA256 hash
SHA256="SHA-256:$(shasum -a 256 "$REPO-$VNUM.tar.bz2" | awk '{print $1}')"

# Create Github download URL
URL="https://${OWNER}.github.io/$REPO-$VNUM.tar.bz2"

# Create board entries

cp "package_debug_enabled_index.json" "package_debug_enabled_index.json.tmp"

# Add new boards release entry
echo $REPO
echo $NICENAME
echo $PAONUM
echo $VNUM
echo $URL
echo $SHA256
echo $FILE_SIZE

jq -r \
--slurpfile boards        extras/${REPO}_boards.json    \
--slurpfile deps          extras/${REPO}_deps.json      \
--arg nice_name           "$NICENAME"                     \
--arg avrocd_toolsversion $PAONUM                       \
--arg repository          $REPO                         \
--arg version             $VNUM                         \
--arg url                 $URL                          \
--arg checksum            $SHA256                       \
--arg file_size           $FILE_SIZE                    \
--arg file_name           $REPO-$VNUM.tar.bz2           \
'.packages[.packages | to_entries | .[] | select(.value.name==$repository) | .key].platforms[.packages[.packages | to_entries | .[] | select(.value.name==$repository) | .key].platforms | length] |= . +
{
  "name": $nice_name,
  "architecture": "avr",
  "version": $version,
  "category": "Contributed",
  "url": $url,
  "archiveFileName": $file_name,
  "checksum": $checksum,
  "size": $file_size,
  "boards": $boards,
  "toolsDependencies": $deps + 
   [
            {
                "packager": $repository,
                "name": "avrocd-tools",
                "version": $avrocd_toolsversion
            }
   ]
}' "package_debug_enabled_index.json.tmp" > "package_debug_enabled_index.json"

# Remove files that are no longer needed
rm -rf "$REPO-$VNUM" "package_debug_enabled_index.json.tmp"

