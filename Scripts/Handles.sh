#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

#修补命令统一入口：FIX <名称> <守卫目录> <命令...>
#守卫目录不存在时直接跳过，保证在 bash -e 下不中断
FIX() {
	local NAME=$1
	local GUARD=$2
	shift 2

	[ -d "$GUARD" ] || return 0

	echo " "
	if "$@"; then
		echo "$NAME has been fixed!"
	else
		echo "$NAME fix failed; continuing!"
	fi
}

#修改argon主题字体和颜色
FIX "theme-argon" "$PACKAGE_PATH/luci-theme-argon" sed -i \
	"s/primary '.*'/primary '#31a1a1'/g; s/'0.2'/'0.5'/g; s/'none'/'bing'/g; s/'600'/'normal'/g" \
	"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"

#修改aurora菜单式样
FIX "theme-aurora" "$PACKAGE_PATH/luci-app-aurora-config" find \
	"$PACKAGE_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec sed -i \
	"s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +

#修改mini-diskmanager菜单位置
FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

#修改natmapt菜单位置
FIX "natmapt" "$PACKAGE_PATH/luci-app-natmapt" sed -i "s/network/services/g" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json"

#修复Rust编译失败
FIX "rust" "$FEEDS_PATH/packages/lang/rust" sed -i 's/ci-llvm=true/ci-llvm=false/g' \
	"$FEEDS_PATH/packages/lang/rust/Makefile"

# ===================== AX3600 双设备配置 =====================
# 清空默认设备列表，只保留ax3600两个profile
target_device_del_all
target_device_add "xiaomi_ax3600"
target_device_add "xiaomi_ax3600-stock"

# ===================== ath11k-nss补丁注入 =====================
echo "====== [Handles.sh] 开始注入ath11k-nss补丁集 ======"
# OPENWRT_PATH 为CI框架内置变量，指向immortalwrt源码目录
if [ -z "${OPENWRT_PATH}" ] || [ ! -d "${OPENWRT_PATH}" ];then
    echo "ERROR: OPENWRT_PATH 无效，跳过所有补丁注入！"
else
    PATCH_RAW_PREFIX="https://raw.githubusercontent.com/mahaprajna/OpenWRT-CI-VIKINGYFY/main/patches/ath11k-nss"
    PATCH_LIST=(
    "0001-ath11k-add-nss-support.patch"
    "0002-ath11k-nss-disable-mesh-path.patch"
    )

    MAC80211_PATCH_DIR="${OPENWRT_PATH}/package/kernel/mac80211/patches/ath11k"
    mkdir -p "${MAC80211_PATCH_DIR}"

    for p in "${PATCH_LIST[@]}";do
        echo "下载补丁: ${p}"
        if ! curl -fsSL "${PATCH_RAW_PREFIX}/${p}" -o "${MAC80211_PATCH_DIR}/${p}";then
            echo "WARN: ${p} 下载失败，跳过此补丁"
        fi
    done

    # 进入源码目录打补丁
    pushd "${OPENWRT_PATH}" >/dev/null
    for p in "${PATCH_LIST[@]}";do
        P_FPATH="${MAC80211_PATCH_DIR}/${p}"
        if [ -f "${P_FPATH}" ];then
            echo "应用补丁 ${p}"
            if ! patch -p1 --no-backup-if-mismatch < "${P_FPATH}";then
                echo "WARN: ${p} 打补丁失败(hunk冲突)，继续运行"
            fi
        fi
    done
    popd >/dev/null
    echo "====== [Handles.sh] ath11k-nss补丁注入完成 ======"

    # ===================== AX3600大分区DTS补丁注入 =====================
    echo "====== [Handles.sh] 应用AX3600大分区DTS补丁 ======"
    DTS_PATCH_RAW="https://raw.githubusercontent.com/mahaprajna/OpenWRT-CI-VIKINGYFY/main/patches/target/qualcommax/ipq807x/0001-xiaomi-ax3600-big-partition.patch"
    DTS_TMP="${OPENWRT_PATH}/0001-xiaomi-ax3600-big-partition.patch"

    if curl -fsSL "${DTS_PATCH_RAW}" -o "${DTS_TMP}";then
        pushd "${OPENWRT_PATH}" >/dev/null
        if ! patch -p1 --no-backup-if-mismatch < "${DTS_TMP}";then
            echo "WARN:DTS大分区补丁打补丁失败(hunk冲突)"
        fi
        popd >/dev/null
    else
        echo "WARN:DTS大分区补丁下载失败"
    fi
    echo "====== [Handles.sh] DTS大分区补丁完成 ======"
fi
