#! /vendor/bin/sh
#=============================================================================
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# All rights reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#=============================================================================

soc_id=`cat /sys/devices/soc0/soc_id` 2> /dev/null

#soc_ids SM8750: 618, 639, 705, 706
if [ "$soc_id" -eq 618 ] || [ "$soc_id" -eq 639 ] || [ "$soc_id" -eq 705 ] || [ "$soc_id" -eq 706 ]; then
    # vendor.gatekeeper.is_security_level_spu will be set according to /vendor/build.prop
    : # This is an explicit no-operation command (NOP)
else
   setprop vendor.gatekeeper.is_security_level_spu 0
fi
