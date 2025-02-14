#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

export TARGET_ENABLE_CHECKELF=false

# If XML files don't have comments before the XML header, use this flag
# Can still be used with broken XML files by using blob_fixup
export TARGET_DISABLE_XML_FIXING=true

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_FIRMWARE=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common)
            ONLY_COMMON=true
            ;;
        --only-firmware)
            ONLY_FIRMWARE=true
            ;;
        --only-target)
            ONLY_TARGET=true
            ;;
        -n | --no-cleanup)
            CLEAN_VENDOR=false
            ;;
        -k | --kang)
            KANG="--kang"
            ;;
        -s | --section)
            SECTION="${2}"
            shift
            CLEAN_VENDOR=false
            ;;
        *)
            SRC="${1}"
            ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        odm/bin/hw/vendor.pixelworks.hardware.display.iris-service)
            [ "$2" = "" ] && return 0
            grep -q "libprocessgroup.so" "${2}" || "${PATCHELF}" --add-needed "libprocessgroup.so" "${2}"
            ;;
        odm/etc/camera/CameraHWConfiguration.config)
            [ "$2" = "" ] && return 0
            sed -i "/SystemCamera = / s/1;/0;/g" "${2}"
            sed -i "/SystemCamera = / s/0;$/1;/" "${2}"
            ;;
        product/etc/sysconfig/com.android.hotwordenrollment.common.util.xml)
            [ "$2" = "" ] && return 0
            sed -i "s/\/my_product/\/product/" "${2}"
            ;;
        system_ext/lib64/libwfdmmsrc_system.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libgui_shim.so" "${2}"
            "${PATCHELF}" --replace-needed "android.hidl.base@1.0.so" "libhidlbase.so" "${2}"
            ;;
            system_ext/lib64/libwfdnative.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libinput_shim.so" "${2}"
            "${PATCHELF}" --replace-needed "android.hidl.base@1.0.so" "libhidlbase.so" "${2}"
            ;;
        vendor/bin/hw/android.hardware.security.keymint-service-qti)
            [ "$2" = "" ] && return 0
            ${PATCHELF} --add-needed "android.hardware.security.rkp-V3-ndk.so" "${2}"
            ;;
        vendor/etc/media_*/video_system_specs.json)
            [ "$2" = "" ] && return 0
            sed -i "/max_retry_alloc_output_timeout/ s/2000/0/" "${2}"
            ;;
        system_ext/framework/oplus-ims-ext.jar)
            [ "$2" = "" ] && return 0
            apktool_patch "${2}" "${MY_DIR}/configs/blob-patches/oplus-ims-ext.patch" -r
            ;;
        vendor/etc/libnfc-nci.conf)
            [ "$2" = "" ] && return 0
            sed -i "s/NFC_DEBUG_ENABLED=1/NFC_DEBUG_ENABLED=0/" "${2}"
            ;;
        vendor/etc/libnfc-nxp.conf)
            [ "$2" = "" ] && return 0
            sed -i "/NXPLOG_\w\+_LOGLEVEL/ s/0x03/0x02/" "${2}"
            sed -i "s/NFC_DEBUG_ENABLED=1/NFC_DEBUG_ENABLED=0/" "${2}"
            ;;
        vendor/etc/media_codecs.xml|vendor/etc/media_codecs_taro.xml|vendor/etc/media_codecs_taro_vendor.xml)
            [ "$2" = "" ] && return 0
            sed -Ei "/media_codecs_(google_audio|google_c2|google_telephony)/d" "${2}"
            sed -i "s/media_codecs_vendor_audio/media_codecs_dolby_audio/" "${2}"
            ;;
        vendor/etc/msm_irqbalance.conf)
            [ "$2" = "" ] && return 0
            sed -i "s/IGNORED_IRQ=27,23,38$/&,115,332/" "${2}"
            ;;
        vendor/lib64/libstagefright_soft_ddpdec.so | vendor/lib64/libdlbdsservice.so | \
        vendor/lib64/libstagefright_soft_ac4dec.so | vendor/lib64/libstagefrightdolby.so)
            [ "$2" = "" ] && return 0
            ${PATCHELF} --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/etc/seccomp_policy/qwesd@2.0.policy)
            [ "$2" = "" ] && return 0
            grep -q "gettid: 1" "${2}" || echo -e "\ngettid: 1" >> "${2}"
            grep -q "pipe2: 1" "${2}" || echo -e "\pipe2: 1" >> "${2}"
            ;;
        system_ext/etc/camera/mtCalibrationCfg.xml)
            [ "$2" = "" ] && return 0
            sed -i "s/-----/--/" "${2}"
            ;;
        system_ext/etc/camera/mwCalibrationCfg.xml)
            [ "$2" = "" ] && return 0
            sed -i "s/-----/--/" "${2}"
            ;;
        odm/lib64/libaps_frame_registration.so|odm/lib64/libCOppLceTonemapAPI.so|odm/lib64/libCS.so|odm/lib64/libSuperRaw.so|odm/lib64/libYTCommon.so|odm/lib64/libyuv2.so|odm/lib64/libPerfectColor.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF_0_17_2}" --replace-needed "libstdc++.so" "libstdc++_vendor.so" "${2}"
            ;;
        vendor/lib64/vendor.libdpmframework.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libhidlbase_shim.so" "${2}"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

function blob_fixup_dry() {
    blob_fixup "$1" ""
}

if [ -z "${ONLY_FIRMWARE}" ] && [ -z "${ONLY_TARGET}" ]; then
    # Initialize the helper for common device
    setup_vendor "${DEVICE_COMMON}" "${VENDOR_COMMON:-$VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../../${VENDOR}/${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../../${VENDOR}/${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    if [ -z "${ONLY_FIRMWARE}" ]; then
        extract "${MY_DIR}/../../${VENDOR}/${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
    fi

    if [ -z "${SECTION}" ] && [ -f "${MY_DIR}/../../${VENDOR}/${DEVICE}/proprietary-firmware.txt" ]; then
        extract_firmware "${MY_DIR}/../../${VENDOR}/${DEVICE}/proprietary-firmware.txt" "${SRC}"
    fi
fi

"${MY_DIR}/setup-makefiles.sh"
