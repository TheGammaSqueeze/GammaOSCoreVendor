#!/vendor/bin/sh
# Copyright (c) 2020-2021, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name of The Linux Foundation nor the names of its
#       contributors may be used to endorse or promote products derived
#      from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Changes from Qualcomm Technologies, Inc. are provided under the following license:
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

target=`getprop ro.board.platform`
platform_subtype_id=0
if [ -f /sys/devices/soc1/soc_id ]; then
    soc_hwid=`cat /sys/devices/soc1/soc_id`
elif [ -f /sys/devices/system/soc/soc1/id ]; then
    soc_hwid=`cat /sys/devices/system/soc/soc1/id`
elif [ -f /sys/devices/soc0/soc_id ]; then
    soc_hwid=`cat /sys/devices/soc0/soc_id`
else
    soc_hwid=`cat /sys/devices/system/soc/soc0/id`
fi

if [ -f /sys/devices/soc1/platform_subtype_id ]; then
    platform_subtype_id=`cat /sys/devices/soc1/platform_subtype_id`
elif [ -f /sys/devices/soc0/platform_subtype_id ]; then
    platform_subtype_id=`cat /sys/devices/soc0/platform_subtype_id`
fi

case "$target" in
    "art")
    # SOC ID for Art is 707
    # SOC ID for Art P is 708
    # SOC ID for Art L is 755
    # SOC ID for Art H is 760
    # SOC ID for Pebble is 735
    # SOC ID for Pebble APQ is 741
    case "$soc_hwid" in
      707|708|755|760|735|741)
        setprop vendor.display.target.version 6
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.thermal.version 1
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.display.refresh_rate_changeable 1
        setprop vendor.display.disable_pu_ds 1
        setprop vendor.display.force_gpu_composition 0
        setprop vendor.display.enable_spec_fence 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_inline_writeback 1
        setprop vendor.display.disable_noise_layer 1
        ;;
    esac
    ;;
    "vienna")
    #SOC ID for Vienna is 669, Vienna P is 670
    case "$soc_hwid" in
      669|670)
        setprop vendor.display.target.version 6
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.thermal.version 1
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_spec_fence 1
        setprop vendor.display.enable_inline_writeback 1
        setprop vendor.display.enable_optimal_refresh_rate 1
        setprop vendor.display.refresh_rate_changeable 1
        ;;
    esac
    ;;
    "shikra")
    #SOC ID for shikra varaints
    case "$soc_hwid" in
      759 | 758 | 756)
        setprop vendor.display.target.version 6
        setprop vendor.display.enable_rotator_ui 0
        setprop vendor.display.thermal.version 1
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_spec_fence 1
        setprop vendor.display.enable_inline_writeback 0
        setprop vendor.display.enable_optimal_refresh_rate 1
        setprop vendor.display.refresh_rate_changeable 1
        ;;
    esac
    ;;
    "bengal")
    setprop vendor.gralloc.use_dma_buf_heaps 1
    setprop vendor.gralloc.hw_supports_ubwcp 0
    setprop vendor.gralloc.enable_snapalloc 1
    setprop vendor.display.enable_posted_start_dyn 2
    setprop vendor.display.enable_allow_idle_fallback 1
    setprop vendor.display.enable_perf_hint_large_comp_cycle 1
    setprop vendor.display.enable_rotator_ui 0
    setprop vendor.display.enable_spec_fence 1
    setprop vendor.display.thermal.version 1
    setprop vendor.display.enable_rc_support 1
    setprop vendor.display.target.version 2
    setprop vendor.display.enable_qsync_idle 0
    setprop vendor.display.disable_mitigated_fps 1
    setprop vendor.display.secure_preview_buffer_format 420_sp
    setprop vendor.gralloc.secure_preview_buffer_format 420_sp
    setprop vendor.display.disable_non_wfd_vds 1
    setprop vendor.display.supports_background_blur 0
    setprop vendor.display.disable_get_screen_decorator_support 1
    setprop vendor.display.enable_async_vds_creation 0
    setprop vendor.display.disable_sdr_dimming 1
    setprop vendor.display.enable_hdr10_gpu_target 0
    setprop vendor.display.enable_dpps_dynamic_fps 0
    setprop vendor.display.vds_allow_hwc 1
    setprop vendor.gralloc.use_uncached_heap 1
    # Set property to differentiate bengal and khaje
    # Soc Id for khaje is 518
    # Soc Id for khaje APQ is 561
    # Soc Id for khaje Gaming is 585 and IOT is 586
    case "$soc_hwid" in
        518|561|585|586)
        # Set property for khaje
        setprop vendor.display.disable_layer_stitch 1
        setprop vendor.display.enable_rounded_corner 1
        setprop vendor.display.disable_rounded_corner_thread 0
        setprop vendor.display.enable_rc_support 1
        ;;
        417|420|444|445)
        # Set property for bengal
        setprop vendor.display.disable_layer_stitch 0
        ;;
        473|474)
        setprop vendor.gralloc.disable_ubwc 1
        ;;
    esac
    ;;
    "canoe"|"hamoa")
    # SOC ID for Canoe is 660
    # SOC ID for Canoe APQ is 661
    # SOC ID for KaM is 704
    # SOC ID for Alor is 685
    # SOC ID for Alor APQ is 727
    # SOC ID for Alor IoT APQ is 764
    # SOC ID for Purwa is 635
    # SOC ID for CanoeS is 722
    # SOC ID for CanoeS APQ is 723
    # SOC ID for Canoe auto is 730
    # SOC ID for Canoe Compute SKU and APQ SKU is 743
    # SOC ID for Hamoa is 555
    case "$soc_hwid" in
      660|661|704|685|727|635|743|722|723|730|555|764)
        setprop vendor.display.target.version 6
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.thermal.version 1
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_spec_fence 1
        if [ "$soc_hwid" -ne 635 ] && [ "$soc_hwid" -ne 555 ]; then
           setprop vendor.display.enable_inline_writeback 1
        else
           setprop vendor.display.disable_cwb_idle_fallback 1
        fi
        # Enable null display for Hamoa QCB and set Hamoa-specific properties
        if [ "$soc_hwid" -eq 555 ]; then
          if [ "$platform_subtype_id" -eq 43 ]; then
            setprop vendor.display.enable_null_display 1
          fi
          setprop vendor.display.disable_dpps_features 1
        fi
        setprop vendor.display.enable_optimal_refresh_rate 1
        setprop vendor.display.refresh_rate_changeable 1
        setprop vendor.display.enable_brightness_drm_prop 1
        setprop vendor.display.enable_idle_content_fps_hint 1
        ;;
    esac
    ;;
    "pikachu")
    # SOC ID for Pikachu is 736
    # SOC ID for Pikachu is 737
    case "$soc_hwid" in
      736|737)
        setprop vendor.display.target.version 6
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.thermal.version 1
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_spec_fence 0
        setprop vendor.display.enable_inline_writeback 1
        setprop vendor.display.enable_optimal_refresh_rate 1
        setprop vendor.display.refresh_rate_changeable 1
        setprop vendor.display.idle_time 0
        setprop vendor.display.idle_time_inactive 0
        setprop vendor.display.disable_cwb_idle_fallback 1
        setprop vendor.display.disable_multirect 1
        setprop vendor.display.disable_llcbc_support 1
        setprop vendor.display.enable_rounded_corner 0
        setprop vendor.display.perf_version 2
        setprop vendor.display.minimum_large_comp_fps 60
        ;;
    esac
    ;;
    "seraph")
    # SOC ID for Seraph is 672
    # SOC ID for Seraph is 673
    case "$soc_hwid" in
      672|673)
        setprop vendor.display.target.version 6
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.thermal.version 1
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_spec_fence 0
        setprop vendor.display.enable_inline_writeback 1
        setprop vendor.display.enable_optimal_refresh_rate 1
        setprop vendor.display.refresh_rate_changeable 1
        setprop vendor.display.idle_time 0
        setprop vendor.display.idle_time_inactive 0
        setprop vendor.display.disable_cwb_idle_fallback 1
        setprop vendor.display.disable_multirect 1
        setprop vendor.display.disable_llcbc_support 1
        setprop vendor.display.enable_rounded_corner 0
        setprop vendor.display.perf.version 2
        setprop vendor.display.minimum_large_comp_fps 60
        ;;
    esac
    ;;
    "sun")
    #SOC ID for Sun is 618
    #SOC ID for Sun APQ is 639
    #SOC ID for CQ8750S is 705
    #SOC ID for CQ8725S is 706
    case "$soc_hwid" in
      618|639|705|706)
        setprop vendor.display.enable_fb_scaling 0
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.target.version 6
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.enable_spec_fence 1
        setprop vendor.display.thermal.version 1
        setprop vendor.display.enable_rc_support 1
        setprop vendor.display.enable_latch_media_content 1
        setprop vendor.display.enable_inline_writeback 1
        setprop vendor.display.timed_render_enable 1
        setprop vendor.gralloc.hw_supports_ubwcp 0
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.display.enable_idle_content_fps_hint 1
        setprop vendor.display.enable_optimal_refresh_rate 1
        setprop vendor.display.refresh_rate_changeable 1
        setprop debug.sf.enable_vrr_config 1
        setprop vendor.display.enable_hal_self_refresh 1
        setprop vendor.display.cpu_cluster_boost_mask 3
        ;;
      655|681|659|694|686|720|721|731|732)
        #SOC ID for tuna is 655
        #SOC ID for tuna7 is 681
        #SOC ID for tuna APQ is 694
        #SOC ID for kera is 659
        #SOC ID for kera is 686
        #SOC ID for kera is 720
        #SOC ID for kera is 721
        #SOC ID for kera iot with Modem is 731
        #SOC ID for kera iot without Modem is 732
        setprop vendor.display.enable_fb_scaling 0
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.target.version 6
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.enable_spec_fence 1
        setprop vendor.display.thermal.version 2
        setprop vendor.display.enable_rc_support 1
        setprop vendor.display.enable_latch_media_content 1
        setprop vendor.display.enable_inline_writeback 1
        setprop vendor.display.timed_render_enable 1
        setprop vendor.gralloc.hw_supports_ubwcp 0
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.display.enable_idle_content_fps_hint 1
        setprop vendor.display.enable_optimal_refresh_rate 1
        setprop vendor.display.refresh_rate_changeable 1
        setprop vendor.display.cpu_cluster_boost_mask 15
        ;;
    esac
    ;;
    "niobe")
    #SOC ID for niobe is 629
    case "$soc_hwid" in
        629|652)
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.thermal.version 1
        setprop vendor.display.enable_rc_support 0
        setprop vendor.display.target.version 5
        setprop vendor.display.disable_mitigated_fps 1
        setprop vendor.display.disable_cwb_idle_fallback 1
        setprop vendor.display.enable_rounded_corner 0  #disable HW RC
        setprop vendor.display.idle_time 0  #disable idle fallback
        setprop vendor.display.idle_time_inactive 0  #disable idle fallback
        setprop vendor.display.use_smooth_motion 0  #disable smooth motion
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.gralloc.hw_supports_ubwcp 0
        setprop vendor.display.disable_dpps_features 1
        ;;
    esac
    ;;
    "pineapple")
    #SOC ID for Pineapple is 557
    case "$soc_hwid" in
      557)
        setprop vendor.display.enable_fb_scaling 0
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.target.version 4
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.enable_spec_fence 1
        setprop vendor.display.thermal.version 1
        setprop vendor.display.enable_rc_support 1
        setprop vendor.display.enable_latch_media_content 1
        setprop vendor.display.enable_inline_writeback 1
        setprop vendor.display.timed_render_enable 1
        setprop vendor.gralloc.hw_supports_ubwcp 0
        setprop vendor.gralloc.enable_snapalloc 1
        ;;
      614|632)
        # SOC ID for Palawan is 614
        # SOC ID for Lamma is 632
        setprop vendor.display.enable_fb_scaling 0
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.target.version 5
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.enable_spec_fence 1
        setprop vendor.display.thermal.version 1
        setprop vendor.display.enable_rc_support 1
        setprop vendor.display.enable_latch_media_content 1
        setprop vendor.display.enable_inline_writeback 1
        setprop vendor.display.timed_render_enable 1
        setprop vendor.gralloc.hw_supports_ubwcp 0
        ;;
    esac
    ;;
    "kalama")
    #SOC ID for Kalama is 519
    case "$soc_hwid" in
      519)
        setprop vendor.display.enable_fb_scaling 0
        setprop vendor.display.target.version 4
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.enable_spec_fence 0
        setprop vendor.display.thermal.version 1
        setprop vendor.display.enable_rc_support 1
        setprop vendor.display.enable_latch_media_content 1
        setprop vendor.display.enable_inline_writeback 1
        setprop vendor.display.timed_render_enable 1
        setprop debug.sf.disable_client_composition_cache 0
        setprop vendor.gralloc.hw_supports_ubwcp 0
        ;;
    esac
    ;;
    "taro")
    #Set property to differentiate Waipio
    #SOC ID for Waipio is 457
    #SOC ID for Cape MSM is 530
    #SOC ID for Cape APQ is 531
    #SOC ID for Cape 4g is 540
    case "$soc_hwid" in
        457)
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.enable_spec_fence 0
        setprop vendor.display.thermal.version 1
        setprop vendor.display.enable_rc_support 1
        setprop vendor.display.target.version 3
        setprop vendor.display.enable_fb_scaling 0
        setprop vendor.display.disable_cwb_idle_fallback 1
        ;;
        530|531|540)
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.enable_spec_fence 0
        setprop vendor.display.thermal.version 1
        setprop vendor.display.enable_rc_support 1
        setprop vendor.display.target.version 2
        setprop vendor.display.enable_qsync_idle 1
        setprop vendor.display.disable_cwb_idle_fallback 1
        ;;
        506|547)
        # Set property for Diwali
        # SOC ID for Diwali is 506
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.enable_spec_fence 0
        setprop vendor.display.thermal.version 1
        setprop vendor.display.enable_rc_support 1
        setprop vendor.display.target.version 2
        setprop vendor.display.enable_qsync_idle 1
        ;;
    esac
    ;;
    "lahaina")
    #Set property to differentiate Lahaina & Shima
    #SOC ID for Lahaina is 415, Lahaina P is 439, Lahaina-ATP is 456
    case "$soc_hwid" in
        415|439|456)
        # Set property for lahaina
        setprop vendor.display.target.version 1
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_allow_idle_fallback 1
        ;;
        450)
        # Set property for shima
        setprop vendor.display.target.version 2
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_posted_start_dyn 1
        setprop vendor.display.enable_qsync_idle 1
        setprop vendor.display.enable_allow_idle_fallback 1
        ;;
        475)
        # Set property for Yupik
        setprop vendor.display.enable_posted_start_dyn 2
        ;;
    esac
    ;;
    "neo61")
    case "$soc_hwid" in
        554)
        setprop vendor.display.enable_null_display 1
        ;;
        579)
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.thermal.version 1
        setprop vendor.display.target.version 3
        setprop vendor.display.disable_mitigated_fps 1
        setprop vendor.display.enable_rounded_corner 0
        setprop vendor.display.wait_for_primary_display 1
        setprop vendor.display.force_gpu_composition 1
        setprop vendor.display.allow_tonemap_native 1
        ;;
        # Set property for Aliso
        740)
        setprop vendor.display.enable_rounded_corner 0
        ;;
    esac
    ;;
    "holi")
    # Set property for holi
    setprop vendor.display.target.version 2
    setprop vendor.display.disable_offline_rotator 0
    setprop vendor.display.disable_rotator_ubwc 1
    setprop vendor.display.enable_perf_hint_large_comp_cycle 0
    setprop vendor.display.enable_posted_start_dyn 1
    setprop vendor.display.enable_allow_idle_fallback 1
    ;;
    "chora")
    case "$soc_hwid" in
      724|744)
        # SOC ID for Chora is 724
        # SOC ID for Chora APQ variant is 744
        setprop vendor.display.enable_fb_scaling 0
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.target.version 5
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_spec_fence 1
        setprop vendor.display.thermal.version 1
        setprop vendor.display.enable_rc_support 1
        setprop vendor.display.enable_inline_writeback 1
        setprop vendor.display.enable_qsync_idle 1
        setprop vendor.display.perf.version 3
        setprop vendor.display.cpu_cluster_boost_mask 6
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.enable_optimal_refresh_rate 1
        setprop vendor.display.refresh_rate_changeable 1
        setprop vendor.display.enable_brightness_drm_prop 1
        setprop vendor.display.enable_idle_content_fps_hint 1
        ;;
      568|602|653|654|581|582)
        # Set property for Ravelin
        # SOC ID for Ravelin is 568
        # SOC ID for Ravelin APQ is 602
        # SOC ID for SG_RAVELIN is 653
        # SOC ID for SG_RAVELIN is 654
        # SOC ID for Ravelin_iot is 581
        # SOC ID for Ravelin_iot is 582
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.enable_spec_fence 1
        setprop vendor.display.thermal.version 1
        setprop vendor.display.enable_rc_support 1
        setprop vendor.display.target.version 5
        setprop vendor.display.enable_qsync_idle 1
        setprop vendor.display.disable_mitigated_fps 1
        setprop vendor.display.secure_preview_buffer_format 420_sp
        setprop vendor.gralloc.secure_preview_buffer_format 420_sp
        setprop vendor.display.disable_cwb_idle_fallback 1
        setprop vendor.display.enable_inline_writeback 1
        setprop vendor.display.enable_rotator_concurrency 1
        setprop vendor.display.disable_offline_rotator 0
        setprop vendor.display.disable_rotator_ubwc 1
        setprop vendor.display.supports_background_blur 0
        setprop vendor.gralloc.hw_supports_ubwcp 0
        setprop vendor.gralloc.enable_snapalloc 1
        setprop vendor.display.disable_get_screen_decorator_support 1
        setprop debug.sf.enable_hwc_vds 0
        setprop persist.sys.sf.color_mode 7
        setprop vendor.display.disable_sdr_dimming 1
        if [ "$soc_hwid" -eq 653 ] || [ "$soc_hwid" -eq 654 ]; then
            setprop vendor.display.enable_latch_media_content 1
        fi
        ;;
    esac
    ;;
    "malabar")
    #SOC ID for Malabar is 733
    #SOC ID for Malabar APQ variant is 757
    case "$soc_hwid" in
      733|757)
        setprop vendor.display.enable_fb_scaling 0
        setprop vendor.gralloc.use_dma_buf_heaps 1
        setprop vendor.display.target.version 5
        setprop vendor.display.enable_posted_start_dyn 2
        setprop vendor.display.enable_allow_idle_fallback 1
        setprop vendor.display.enable_perf_hint_large_comp_cycle 1
        setprop vendor.display.enable_rotator_ui 1
        setprop vendor.display.enable_spec_fence 1
        setprop vendor.display.thermal.version 1
        setprop vendor.display.enable_rc_support 1
        setprop vendor.display.enable_inline_writeback 0
        setprop vendor.display.disable_gpu_color_convert 0
        setprop vendor.display.disable_cwb_idle_fallback 1
        setprop vendor.display.disable_offline_rotator 0
        setprop vendor.display.enable_qsync_idle 1
        setprop vendor.display.disable_rotator_ubwc 1
        setprop vendor.gralloc.allow_camera_preview_write 1
        setprop vendor.display.perf.version 4
        setprop vendor.display.cpu_cluster_boost_mask 6
        setprop vendor.display.enable_optimal_refresh_rate 1
        setprop vendor.display.refresh_rate_changeable 1
        setprop vendor.display.enable_brightness_drm_prop 1
        setprop vendor.gralloc.use_uncached_heap 1
        setprop vendor.display.enable_idle_content_fps_hint 1
        ;;
    esac
    ;;
    "monaco")
    setprop vendor.gralloc.use_dma_buf_heaps 1
    setprop vendor.gralloc.enable_snapalloc 1
    setprop vendor.gralloc.disable_ubwc 1
    setprop vendor.display.enable_optimize_refresh 1
    setprop vendor.display.target.version 2
    setprop vendor.display.enable_allow_idle_fallback 1
    setprop vendor.display.enable_hdr10_gpu_target 0
    setprop vendor.display.enable_rc_support 0
    setprop vendor.display.enable_async_vds_creation 0
    setprop vendor.display.enable_rounded_corner 0
    ;;
esac
