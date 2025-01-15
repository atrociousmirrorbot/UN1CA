#!/usr/bin/env bash
#
# Copyright (C) 2023 BlackMesa123
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

set -Eeuo pipefail

# [
GENERATE_LPMAKE_OPT()
{
    local OPT
    local GROUP_NAME="qti_dynamic_partitions"
    local HAS_SYSTEM=false
    local HAS_VENDOR=false
    local HAS_PRODUCT=false
    local HAS_SYSTEM_EXT=false
    local HAS_ODM=false
    local HAS_VENDOR_DLKM=false
    local HAS_ODM_DLKM=false
    local HAS_SYSTEM_DLKM=false

    [ -f "$TMP_DIR/system.img" ] && HAS_SYSTEM=true
    [ -f "$TMP_DIR/vendor.img" ] && HAS_VENDOR=true
    [ -f "$TMP_DIR/product.img" ] && HAS_PRODUCT=true
    [ -f "$TMP_DIR/system_ext.img" ] && HAS_SYSTEM_EXT=true
    [ -f "$TMP_DIR/odm.img" ] && HAS_ODM=true
    [ -f "$TMP_DIR/vendor_dlkm.img" ] && HAS_VENDOR_DLKM=true
    [ -f "$TMP_DIR/odm_dlkm.img" ] && HAS_ODM_DLKM=true
    [ -f "$TMP_DIR/system_dlkm.img" ] && HAS_SYSTEM_DLKM=true

    OPT+="--sparse"
    OPT+=" -o $TMP_DIR/super.img"
    OPT+=" --device-size $TARGET_SUPER_PARTITION_SIZE"
    OPT+=" --metadata-size 65536 --metadata-slots 2"
    OPT+=" -g $GROUP_NAME:$TARGET_SUPER_GROUP_SIZE"

    if $HAS_SYSTEM; then
        OPT+=" -p system:readonly:$(wc -c "$TMP_DIR/system.img" | cut -d " " -f 1):$GROUP_NAME"
    fi
    if $HAS_VENDOR; then
        OPT+=" -p vendor:readonly:$(wc -c "$TMP_DIR/vendor.img" | cut -d " " -f 1):$GROUP_NAME"
    fi
    if $HAS_PRODUCT; then
        OPT+=" -p product:readonly:$(wc -c "$TMP_DIR/product.img" | cut -d " " -f 1):$GROUP_NAME"
    fi
    if $HAS_SYSTEM_EXT; then
        OPT+=" -p system_ext:readonly:$(wc -c "$TMP_DIR/system_ext.img" | cut -d " " -f 1):$GROUP_NAME"
    fi
    if $HAS_ODM; then
        OPT+=" -p odm:readonly:$(wc -c "$TMP_DIR/odm.img" | cut -d " " -f 1):$GROUP_NAME"
    fi
    if $HAS_VENDOR_DLKM; then
        OPT+=" -p vendor_dlkm:readonly:$(wc -c "$TMP_DIR/vendor_dlkm.img" | cut -d " " -f 1):$GROUP_NAME"
    fi
    if $HAS_ODM_DLKM; then
        OPT+=" -p odm_dlkm:readonly:$(wc -c "$TMP_DIR/odm_dlkm.img" | cut -d " " -f 1):$GROUP_NAME"
    fi
    if $HAS_SYSTEM_DLKM; then
        OPT+=" -p system_dlkm:readonly:$(wc -c "$TMP_DIR/system_dlkm.img" | cut -d " " -f 1):$GROUP_NAME"
    fi

    if $HAS_SYSTEM; then
        OPT+=" -i system=$TMP_DIR/system.img"
    fi
    if $HAS_VENDOR; then
        OPT+=" -i vendor=$TMP_DIR/vendor.img"
    fi
    if $HAS_PRODUCT; then
        OPT+=" -i product=$TMP_DIR/product.img"
    fi
    if $HAS_SYSTEM_EXT; then
        OPT+=" -i system_ext=$TMP_DIR/system_ext.img"
    fi
    if $HAS_ODM; then
        OPT+=" -i odm=$TMP_DIR/odm.img"
    fi
    if $HAS_VENDOR_DLKM; then
        OPT+=" -i vendor_dlkm=$TMP_DIR/vendor_dlkm.img"
    fi
    if $HAS_ODM_DLKM; then
        OPT+=" -i odm_dlkm=$TMP_DIR/odm_dlkm.img"
    fi
    if $HAS_SYSTEM_DLKM; then
        OPT+=" -i system_dlkm=$TMP_DIR/system_dlkm.img"
    fi

    echo "$OPT"
}

FILE_NAME="UN1CA_${ROM_VERSION}_$(date +%Y%m%d)_${TARGET_CODENAME}"
# ]

echo "Set up tmp dir"
mkdir -p "$TMP_DIR"

while read -r i; do
    PARTITION=$(basename "$i")
    [[ "$PARTITION" == "configs" ]] && continue
    [[ "$PARTITION" == "kernel" ]] && continue
    [ -f "$TMP_DIR/$PARTITION.img" ] && rm -f "$TMP_DIR/$PARTITION.img"
    [ -f "$WORK_DIR/$PARTITION.img" ] && rm -f "$WORK_DIR/$PARTITION.img"

    echo "Building $PARTITION.img"
    bash "$SRC_DIR/scripts/build_fs_image.sh" "$TARGET_OS_FILE_SYSTEM" "$WORK_DIR/$PARTITION" \
        "$WORK_DIR/configs/file_context-$PARTITION" "$WORK_DIR/configs/fs_config-$PARTITION" > /dev/null 2>&1
    mv "$WORK_DIR/$PARTITION.img" "$TMP_DIR/$PARTITION.img"
done <<< "$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d)"

rm -f "$TMP_DIR/vendor.img"

for i in "$TMP_DIR"/*.img; do
    if [[ -f "$i" ]]; then
        echo "Compressing $(basename "$i")"
        7z a -mx9 "${i%.*}.img.xz" "$i" && rm "$i"
    fi
done &> /dev/null

for i in "$TMP_DIR"/*.xz; do
    if [[ -f "$i" ]]; then
        echo "Moving $(basename "$i") to $OUT_DIR"
        mv "$i" "$OUT_DIR"
    fi
done

echo "Installing pypi"
sudo sudo pip3 install oauth2client google-api-python-client google-auth-httplib2 google-auth-oauthlib

echo "Uploading .xz files from $OUT_DIR to Google Drive"
sudo python3 upload.py $OUT_DIR

echo "Deleting tmp dir"
rm -rf "$TMP_DIR"

exit 0
