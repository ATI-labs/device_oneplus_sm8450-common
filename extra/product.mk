EXTRA_PATH := vendor/extra

# ADB
ifneq (,$(wildcard $(EXTRA_PATH)/adbkey.pub))
PRODUCT_ADB_KEYS := $(EXTRA_PATH)/adbkey.pub
endif

# Bellis
ifneq (,$(wildcard packages/apps/Bellis))
PRODUCT_PACKAGES += Bellis
endif

# Default ADB shell prompt
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    persist.sys.adb.shell=/system_ext/bin/bash

# Google Apps
ifeq ($(WITH_GMS), true)
$(call inherit-product-if-exists, vendor/gms/arm64/arm64-vendor.mk)
endif

# ih8sn
$(call inherit-product, $(LOCAL_PATH)/ih8sn/ih8sn.mk)

# iperf3
PRODUCT_PACKAGES += iperf3

# tinymix
PRODUCT_PACKAGES += tinymix
