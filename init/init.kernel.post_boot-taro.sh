#=============================================================================
# Copyright (c) 2020-2021 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# Copyright (c) 2009-2012, 2014-2019, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#=============================================================================

echo "powersave" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

echo "powersave" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
echo "powersave" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
echo "powersave" > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor

echo "powersave" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
echo "powersave" > /sys/devices/system/cpu/cpu5/cpufreq/scaling_governor
echo "powersave" > /sys/devices/system/cpu/cpu6/cpufreq/scaling_governor

echo 1804800 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq  # Prime
echo 1324800 > /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq  # Perform>
echo 844800  > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq  # Efficie>

echo 305000000 > /sys/class/kgsl/kgsl-3d0/devfreq/max_freq

echo "powersave" > /sys/class/kgsl/kgsl-3d0/devfreq/governor

echo "noop" > /sys/block/sda/queue/scheduler

for i in 1 2 3 4 5 6; do
    echo 0 > /sys/devices/system/cpu/cpu$i/online
done

for i in 1 2 3 4 5 6; do
    echo 1 > /sys/devices/system/cpu/cpu$i/online
done

echo "powersave" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo 2500000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq

for i in 1 2 3; do
    echo "powersave" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
    echo 2000000 > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq
done

for i in 4 5 6; do
    echo "powersave" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
    echo 1200000 > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq
done

function configure_zram_parameters() {
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}

	# Zram disk - 75% for Go and < 2GB devices .
	# For >2GB Non-Go devices, size = 50% of RAM size. Limit the size to 4GB.
	# And enable lz4 zram compression for Go targets.

	let RamSizeGB="( $MemTotal / 1048576 ) + 1"
	diskSizeUnit=M
	if [ $RamSizeGB -le 2 ]; then
		let zRamSizeMB="( $RamSizeGB * 1024 ) * 3"
	else
		let zRamSizeMB="( $RamSizeGB * 1024 ) * 3"
	fi

	# use MB avoid 32 bit overflow
	if [ $zRamSizeMB -gt 32768 ]; then
		let zRamSizeMB=32768
	fi

	echo lz4 > /sys/block/zram0/comp_algorithm

	if [ -f /sys/block/zram0/disksize ]; then
		if [ -f /sys/block/zram0/use_dedup ]; then
			echo 1 > /sys/block/zram0/use_dedup
		fi
		echo "$zRamSizeMB""$diskSizeUnit" > /sys/block/zram0/disksize

		# ZRAM may use more memory than it saves if SLAB_STORE_USER
		# debug option is enabled.
		if [ -e /sys/kernel/slab/zs_handle ]; then
			echo 0 > /sys/kernel/slab/zs_handle/store_user
		fi
		if [ -e /sys/kernel/slab/zspage ]; then
			echo 0 > /sys/kernel/slab/zspage/store_user
		fi

		echo memlim > /sys/block/zram0/mem_limit
		echo 8 > /sys/block/zram0/max_comp_streams
		mkswap /dev/block/zram0
		swapon /dev/block/zram0 -p 32758
		echo 100 > /proc/sys/vm/swappiness
		echo 15 > /proc/sys/vm/dirty_background_ratio
		echo 200 > /proc/sys/vm/vfs_cache_pressure
		echo 3000 > /proc/sys/vm/dirty_writeback_centisecs
		echo 3 > /proc/sys/vm/drop_caches
		echo 0 > /proc/sys/vm/oom_kill_allocating_task
		echo "256,10240,32000,34000,36000,38000" > /sys/module/lowmemorykiller/parameters/minfree

		echo 70 > /dev/memcg/memory.swapd_max_reclaim_size
		echo "1000 50" > /dev/memcg/memory.swapd_shrink_parameter
		echo 5000 > /dev/memcg/memory.max_skip_interval
		echo 50 > /dev/memcg/memory.reclaim_exceed_sleep_ms
		echo 60 > /dev/memcg/memory.cpuload_threshold
		echo 30 > /dev/memcg/memory.max_reclaimin_size_mb
		echo 80 > /dev/memcg/memory.zram_wm_ratio
		echo 512 > /dev/memcg/memory.empty_round_skip_interval
		echo 20 > /dev/memcg/memory.empty_round_check_threshold

		echo apps >/dev/memcg/apps/memory.name
		echo 300 > /dev/memcg/apps/memory.app_score
		echo root > /dev/memcg/memory.name
		echo 400 > /dev/memcg/memory.app_score
		cat /sys/module/lowmemorykiller/parameters/minfree
	fi
}

function configure_read_ahead_kb_values() {

	dmpts=$(ls /sys/block/*/queue/read_ahead_kb | grep -e dm -e mmc)

	ra_kb=128

	if [ -f /sys/block/mmcblk0/bdi/read_ahead_kb ]; then
		echo $ra_kb > /sys/block/mmcblk0/bdi/read_ahead_kb
	fi
	if [ -f /sys/block/mmcblk0rpmb/bdi/read_ahead_kb ]; then
		echo $ra_kb > /sys/block/mmcblk0rpmb/bdi/read_ahead_kb
	fi
	for dm in $dmpts; do
		if [ `cat $(dirname $dm)/../removable` -eq 0 ]; then
			echo $ra_kb > $dm
		fi
	done
}

function start_retasker() {
  local cpuctl=/dev/cpuctl  
  for i in $(find $cpuctl -type d -mindepth 1 -maxdepth 1); do    
    for task in $(cat $i/tasks); do
      echo $task > $cpuctl/cgroup.procs
    done    
    case $(basename "$i") in
      top-app)
        write $i/cpu.shares 1024
        write $i/cpu.uclamp.max max
        write $i/cpu.uclamp.min 10
      ;;
      foreground)
        write $i/cpu.shares 208
        write $i/cpu.uclamp.max 20
        write $i/cpu.uclamp.min 5
      ;;
      background)
        write $i/cpu.shares 52
        write $i/cpu.uclamp.max 10
        write $i/cpu.uclamp.min 0
      ;;
  done
}

function start_hypnus() {
  write /sys/devices/platform/soc/soc:oplus-omrg/oplus-omrg0/ruler_enable 0
  local cpu=/sys/devices/system/cpu
  for i in 0 1 2 3 4 5 6 7; do    
    cpu_max_freq=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq)
    write /sys/kernel/msm_performance/parameters/cpu_max_freq $i:$cpu_max_freq
    #write $cpu/cpu$i/online 1
    #write $cpu/cpu$i/hotplug/target 222
  done

  echo 0 > /proc/sys/walt/sched_min_task_util_for_colocation
  echo 0 > /proc/sys/walt/sched_min_task_util_for_boost
  
  local kgsl=/sys/class/kgsl/kgsl-3d0
  write $kgsl/max_clock_mhz 545  
  write $kgsl/throttling 0
  write $kgsl/bus_split 0
  write $kgsl/force_bus_on 1
  write $kgsl/force_clk_on 1
  write $kgsl/force_no_nap 1
  write $kgsl/force_rail_on 1
  write $kgsl/idle_timer 1000000
}

function start_hotfix() {  
  setprop debug.refresh_rate.view_override 0
  setprop vendor.display.refresh_rate_changeable 1  
  write /sys/class/oplus_chg/battery/cool_down 3
}

function start_sysctl() {
  local vm=/proc/sys/vm
  echo 120 > $vm/swappiness
  echo 11264 > $vm/extra_free_kbytes
  echo 5120 > $vm/min_free_kbytes

  local kn=/proc/sys/kernel
  echo 5000000 > $kn/sched_latency_ns
  echo 5000000 > $kn/sched_migration_cost_ns
  echo 5000000 > $kn/sched_min_granularity_ns 
  echo 3400000 > $kn/sched_rt_period_us
  echo 3350000 > $kn/sched_rt_runtime_us
  echo 128 > $kn/sched_nr_migrate
}

function configure_memory_parameters() {
	# Set Memory parameters.
	#
	# Set per_process_reclaim tuning parameters
	# All targets will use vmpressure range 50-70,
	# All targets will use 512 pages swap size.
	#
	# Set Low memory killer minfree parameters
	# 32 bit Non-Go, all memory configurations will use 15K series
	# 32 bit Go, all memory configurations will use uLMK + Memcg
	# 64 bit will use Google default LMK series.
	#
	# Set ALMK parameters (usually above the highest minfree values)
	# vmpressure_file_min threshold is always set slightly higher
	# than LMK minfree's last bin value for all targets. It is calculated as
	# vmpressure_file_min = (last bin - second last bin ) + last bin
	#
	# Set allocstall_threshold to 0 for all targets.
	#
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}

	configure_zram_parameters
	configure_read_ahead_kb_values

	# Disable periodic kcompactd wakeups. We do not use THP, so having many
	# huge pages is not as necessary.
	echo 0 > /proc/sys/vm/compaction_proactiveness

	# With THP enabled, the kernel greatly increases min_free_kbytes over its
	# default value. Disable THP to prevent resetting of min_free_kbytes
	# value during online/offline pages.
	# 11584kb is the standard kernel value of min_free_kbytes for 8Gb of lowmem
	if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
		echo never > /sys/kernel/mm/transparent_hugepage/enabled
	fi

	if [ $MemTotal -le 8388608 ]; then
		echo 40 > /proc/sys/vm/watermark_scale_factor
	else
		echo 16 > /proc/sys/vm/watermark_scale_factor
	fi

	echo 0 > /proc/sys/vm/watermark_boost_factor
	echo 11584 > /proc/sys/vm/min_free_kbytes
}

rev=`cat /sys/devices/soc0/revision`
ddr_type=`od -An -tx /proc/device-tree/memory/ddr_device_type`
ddr_type4="07"
ddr_type5="08"

# Core control parameters for gold
echo 2 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
echo 60 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
echo 30 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
echo 100 > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
echo 3 > /sys/devices/system/cpu/cpu4/core_ctl/task_thres

# Core control parameters for gold+
echo 0 > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
echo 60 > /sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres
echo 30 > /sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres
echo 100 > /sys/devices/system/cpu/cpu7/core_ctl/offline_delay_ms
echo 1 > /sys/devices/system/cpu/cpu7/core_ctl/task_thres

# Controls how many more tasks should be eligible to run on gold CPUs
# w.r.t number of gold CPUs available to trigger assist (max number of
# tasks eligible to run on previous cluster minus number of CPUs in
# the previous cluster).
#
# Setting to 1 by default which means there should be at least
# 4 tasks eligible to run on gold cluster (tasks running on gold cores
# plus misfit tasks on silver cores) to trigger assitance from gold+.
echo 1 > /sys/devices/system/cpu/cpu7/core_ctl/nr_prev_assist_thresh

# Disable Core control on silver
echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/enable

# Setting b.L scheduler parameters
echo 95 95 > /proc/sys/walt/sched_upmigrate
echo 85 85 > /proc/sys/walt/sched_downmigrate
echo 100 > /proc/sys/walt/sched_group_upmigrate
echo 85 > /proc/sys/walt/sched_group_downmigrate
echo 1 > /proc/sys/walt/sched_walt_rotate_big_tasks
echo 400000000 > /proc/sys/walt/sched_coloc_downmigrate_ns
echo 39000000 39000000 39000000 39000000 39000000 39000000 39000000 5000000 > /proc/sys/walt/sched_coloc_busy_hyst_cpu_ns
echo 240 > /proc/sys/walt/sched_coloc_busy_hysteresis_enable_cpus
echo 10 10 10 10 10 10 10 95 > /proc/sys/walt/sched_coloc_busy_hyst_cpu_busy_pct
echo 5000000 5000000 5000000 5000000 5000000 5000000 5000000 2000000 > /proc/sys/walt/sched_util_busy_hyst_cpu_ns
echo 255 > /proc/sys/walt/sched_util_busy_hysteresis_enable_cpus
echo 15 15 15 15 15 15 15 15 > /proc/sys/walt/sched_util_busy_hyst_cpu_util

# set the threshold for low latency task boost feature which prioritize
# binder activity tasks
echo 325 > /proc/sys/walt/walt_low_latency_task_threshold

# cpuset parameters
echo 1-2 > /dev/cpuset/audio-app/cpus
echo 0-1 > /dev/cpuset/background/cpus
echo 0-6 > /dev/cpuset/foreground/cpus
echo 0-2 > /dev/cpuset/restricted/cpus
echo 0-3 > /dev/cpuset/system-background/cpus

# Turn off scheduler boost at the end
echo 0 > /proc/sys/walt/sched_boost

# Reset the RT boost, which is 1024 (max) by default.
echo 0 > /proc/sys/kernel/sched_util_clamp_min_rt_default

# configure governor settings for silver cluster
echo "walt" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo 0 > /sys/devices/system/cpu/cpufreq/policy0/walt/down_rate_limit_us
echo 0 > /sys/devices/system/cpu/cpufreq/policy0/walt/up_rate_limit_us
if [ $rev == "1.0" ]; then
	echo 1190400 > /sys/devices/system/cpu/cpufreq/policy0/walt/hispeed_freq
else
	echo 1267200 > /sys/devices/system/cpu/cpufreq/policy0/walt/hispeed_freq
fi
echo 614400 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo 1 > /sys/devices/system/cpu/cpufreq/policy0/walt/pl

# configure governor settings for gold cluster
echo "walt" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
echo 0 > /sys/devices/system/cpu/cpufreq/policy4/walt/down_rate_limit_us
echo 0 > /sys/devices/system/cpu/cpufreq/policy4/walt/up_rate_limit_us
if [ $rev == "1.0" ]; then
	echo 1497600 > /sys/devices/system/cpu/cpufreq/policy4/walt/hispeed_freq
else
	echo 1555200 > /sys/devices/system/cpu/cpufreq/policy4/walt/hispeed_freq
fi
echo 1 > /sys/devices/system/cpu/cpufreq/policy4/walt/pl

# configure governor settings for gold+ cluster
echo "walt" > /sys/devices/system/cpu/cpufreq/policy7/scaling_governor
echo 0 > /sys/devices/system/cpu/cpufreq/policy7/walt/down_rate_limit_us
echo 0 > /sys/devices/system/cpu/cpufreq/policy7/walt/up_rate_limit_us
if [ $rev == "1.0" ]; then
	echo 1536000 > /sys/devices/system/cpu/cpufreq/policy7/walt/hispeed_freq
else
	echo 1728000 > /sys/devices/system/cpu/cpufreq/policy7/walt/hispeed_freq
fi
echo 1 > /sys/devices/system/cpu/cpufreq/policy7/walt/pl

# configure bus-dcvs
bus_dcvs="/sys/devices/system/cpu/bus_dcvs"

for device in $bus_dcvs/*
do
	cat $device/hw_min_freq > $device/boost_freq
done

for llccbw in $bus_dcvs/LLCC/*bwmon-llcc
do
	echo "4577 7110 9155 12298 14236 15258" > $llccbw/mbps_zones
	echo 4 > $llccbw/sample_ms
	echo 80 > $llccbw/io_percent
	echo 20 > $llccbw/hist_memory
	echo 10 > $llccbw/hyst_length
	echo 30 > $llccbw/down_thres
	echo 0 > $llccbw/guard_band_mbps
	echo 250 > $llccbw/up_scale
	echo 1600 > $llccbw/idle_mbps
	echo 806000 > $llccbw/max_freq
	echo 40 > $llccbw/window_ms
done

for ddrbw in $bus_dcvs/DDR/*bwmon-ddr
do
	echo "1720 2086 2929 3879 6515 7980 12191" > $ddrbw/mbps_zones
	echo 4 > $ddrbw/sample_ms
	echo 80 > $ddrbw/io_percent
	echo 20 > $ddrbw/hist_memory
	echo 10 > $ddrbw/hyst_length
	echo 30 > $ddrbw/down_thres
	echo 0 > $ddrbw/guard_band_mbps
	echo 250 > $ddrbw/up_scale
	echo 1600 > $ddrbw/idle_mbps
	echo 2092000 > $ddrbw/max_freq
	echo 40 > $ddrbw/window_ms
done

for latfloor in $bus_dcvs/*/*latfloor
do
	echo 25000 > $latfloor/ipm_ceil
done

for l3gold in $bus_dcvs/L3/*gold
do
	echo 4000 > $l3gold/ipm_ceil
done

for l3prime in $bus_dcvs/L3/*prime
do
	echo 20000 > $l3prime/ipm_ceil
done

for ddrprime in $bus_dcvs/DDR/*prime
do
	echo 25 > $ddrprime/freq_scale_pct
	echo 1881 > $ddrprime/freq_scale_limit_mhz
done

for qosgold in $bus_dcvs/DDRQOS/*gold
do
	echo 50 > $qosgold/ipm_ceil
done

if [ "$rev" == "1.0" ]; then
	echo Y > /sys/devices/system/cpu/qcom_lpm/parameters/sleep_disabled
	echo 1 > /sys/devices/system/cpu/cpu0/cpuidle/state1/disable
	echo 1 > /sys/devices/system/cpu/cpu1/cpuidle/state1/disable
	echo 1 > /sys/devices/system/cpu/cpu2/cpuidle/state1/disable
	echo 1 > /sys/devices/system/cpu/cpu3/cpuidle/state1/disable
	echo 1 > /sys/devices/system/cpu/cpu4/cpuidle/state1/disable
	echo 1 > /sys/devices/system/cpu/cpu5/cpuidle/state1/disable
	echo 1 > /sys/devices/system/cpu/cpu6/cpuidle/state1/disable
	echo 1 > /sys/devices/system/cpu/cpu7/cpuidle/state1/disable
	echo 0 > "/sys/devices/platform/hypervisor/hypervisor:qcom,gh-watchdog/wakeup_enable"
else
	echo N > /sys/devices/system/cpu/qcom_lpm/parameters/sleep_disabled
fi

echo deep > /sys/power/mem_sleep
configure_memory_parameters
start_retasker
start_hypnus
start_hotfix
main_fn

# Let kernel know our image version/variant/crm_version
if [ -f /sys/devices/soc0/select_image ]; then
	image_version="10:"
	image_version+=`getprop ro.build.id`
	image_version+=":"
	image_version+=`getprop ro.build.version.incremental`
	image_variant=`getprop ro.product.name`
	image_variant+="-"
	image_variant+=`getprop ro.build.type`
	oem_version=`getprop ro.build.version.codename`
	echo 10 > /sys/devices/soc0/select_image
	echo $image_version > /sys/devices/soc0/image_version
	echo $image_variant > /sys/devices/soc0/image_variant
	echo $oem_version > /sys/devices/soc0/image_crm_version
fi

# vars
echo 0 > /sys/devices/system/edac/qcom-llcc/panic_on_ue

GPU_PATH=/sys/class/kgsl/kgsl-3d0/max_pwrlevel
POLICY_0_PATH=/sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
POLICY_4_PATH=/sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
POLICY_7_PATH=/sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq

while [ ! -d /sdcard ]; do
    sleep 10
done

# GPU
if [ -f "${GPU_PATH}" ] ; then
    GPU_POWER_LIMIT_ORIG=$(cat "${GPU_PATH}")
else
    exit
fi;

# POLICY_0
if [ -f "${POLICY_0_PATH}" ] ; then
    POLICY_0_MAX_FREQ_ORIG=$(cat "${POLICY_0_PATH}")
else
    exit
fi;

# POLICY_4
if [ -f "${POLICY_4_PATH}" ] ; then
    POLICY_4_MAX_FREQ_ORIG=$(cat "${POLICY_4_PATH}")
else
    exit
fi;

# POLICY_7
if [ -f "${POLICY_7_PATH}" ] ; then
    POLICY_7_MAX_FREQ_ORIG=$(cat "${POLICY_7_PATH}")
else
    exit
fi;
   
# defaults

LIMIT_PROFILE_PREV=initial

main_fn() {
    # reading current system values
    GPU_POWER_LIMIT_TMP=$(cat "${GPU_PATH}")
    POLICY_0_MAX_FREQ_TMP=$(cat "${POLICY_0_PATH}")
    POLICY_4_MAX_FREQ_TMP=$(cat "${POLICY_4_PATH}")
    POLICY_7_MAX_FREQ_TMP=$(cat "${POLICY_7_PATH}")
  
    # choosing new values based on config
    
    GPU_POWER_LIMIT=5
    POLICY_0_MAX_FREQ=1171200
    POLICY_4_MAX_FREQ=1766400
    POLICY_7_MAX_FREQ=1401600
    
    if [ -n "${OVERRIDE_GPU_POWER_LIMIT}" ] ; then
        GPU_POWER_LIMIT=${OVERRIDE_GPU_POWER_LIMIT}
    fi
    if [ -n "${OVERRIDE_POLICY_0_SCALING_MAX_FREQ}" ] ; then
        POLICY_0_MAX_FREQ=${OVERRIDE_POLICY_0_SCALING_MAX_FREQ}
    fi
    if [ -n "${OVERRIDE_POLICY_4_SCALING_MAX_FREQ}" ] ; then
        POLICY_4_MAX_FREQ=${OVERRIDE_POLICY_4_SCALING_MAX_FREQ}
    fi
    if [ -n "${OVERRIDE_POLICY_7_SCALING_MAX_FREQ}" ] ; then
        POLICY_7_MAX_FREQ=${OVERRIDE_POLICY_7_SCALING_MAX_FREQ}
    fi

    if [ "${LIMIT_PROFILE_PREV}" != "${LIMIT_PROFILE}" ] ; then
        LIMIT_PROFILE_PREV="${LIMIT_PROFILE}"
    fi

    # writing new values if needed
    if [ "${GPU_POWER_LIMIT_TMP}" != "${GPU_POWER_LIMIT}" ] ; then
        echo "${GPU_POWER_LIMIT}" > ${GPU_PATH}
    fi
    if [ "${POLICY_0_MAX_FREQ_TMP}" != "${POLICY_0_MAX_FREQ}" ] ; then
        echo "${POLICY_0_MAX_FREQ}" > ${POLICY_0_PATH}
    fi
    if [ "${POLICY_4_MAX_FREQ_TMP}" != "${POLICY_4_MAX_FREQ}" ] ; then
        echo "${POLICY_4_MAX_FREQ}" > ${POLICY_4_PATH}
    fi
    if [ "${POLICY_7_MAX_FREQ_TMP}" != "${POLICY_7_MAX_FREQ}" ] ; then
        echo "${POLICY_7_MAX_FREQ}" > ${POLICY_7_PATH}
    fi

    }

main_fn;

while true; do
    sleep 20

    # do nothing if the device is sleeping
    mWakefulness=$(dumpsys power | grep mWakefulness= | head -1 | cut -d "=" -f2)
    if [ "${mWakefulness}" == "Dozing" ] || [ "${mWakefulness}" == "Asleep" ] ; then
        continue
    fi

    main_fn;
done

# Change console log level as per console config property
console_config=`getprop persist.vendor.console.silent.config`
case "$console_config" in
	"1")
		echo "Enable console config to $console_config"
		echo 0 > /proc/sys/kernel/printk
	;;
	*)
		echo "Enable console config to $console_config"
	;;
esac

setprop vendor.post_boot.parsed 1
