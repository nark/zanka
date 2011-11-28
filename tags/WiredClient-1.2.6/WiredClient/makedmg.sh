#!/bin/sh

SOURCE_FOLDER="$1"
IMAGE_FOLDER="$2"

if [ ! -d "$SOURCE_FOLDER" ]; then
	echo "$0: $SOURCE_FOLDER: No such directory"
	exit 1
fi

if [ ! -d "$IMAGE_FOLDER" ]; then
	echo "$0: $IMAGE_FOLDER: No such directory"
	exit 1
fi

VOLUME_NAME=$(basename "$SOURCE_FOLDER")
IMAGE_PATH="${IMAGE_FOLDER}/${VOLUME_NAME}.dmg"
TEMP_IMAGE_PATH="${IMAGE_FOLDER}/${VOLUME_NAME}_temp.dmg"
MOUNT_PATH="/Volumes/${VOLUME_NAME}"

rm -f "$IMAGE_PATH" "$TEMP_IMAGE_PATH"

FOLDER_BLOCKS=$(/usr/bin/du -s "$SOURCE_FOLDER" | awk '{ print $1 }')
PADDED_FOLDER_BLOCKS=$(expr $FOLDER_BLOCKS \* 2)

if [ $PADDED_FOLDER_BLOCKS -lt 10240 ]; then
    PADDED_FOLDER_BLOCKS=10240
fi

hdiutil create -sectors $PADDED_FOLDER_BLOCKS -layout NONE -fs "HFS+" -volname "$VOLUME_NAME" -srcfolder "$SOURCE_FOLDER" "$TEMP_IMAGE_PATH"

if [ "X$?" != X"0" ] ; then
    echo "$0: $TEMP_IMAGE_PATH: $?"
    exit 1
fi

hdiutil convert -format UDZO -o "$IMAGE_PATH" "$TEMP_IMAGE_PATH"

if [ "X$?" != X"0" ] ; then
    echo "$0: $TEMP_IMAGE_PATH: $?"
    exit 1
fi

rm "$TEMP_IMAGE_PATH"

exit 0
