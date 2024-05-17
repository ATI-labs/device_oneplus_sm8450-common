# Google Apps
ifeq ($(WITH_GMS), true)
-include vendor/gms/arm64/BoardConfigVendor.mk
endif

# ccache
USE_CCACHE := 1
