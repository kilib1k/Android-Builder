#!/bin/bash

echo
echo "--------------------------------------"
echo "        DogDayAndroid Buildbot        "
echo "                by                    "
echo "             easterNday               "
echo "--------------------------------------"
echo

# set -xe
set -e

# 获取脚本所在路径
ROOT=$(cd $(dirname $0);pwd)

# BL=$PWD/treble_build_pe
OUTPUTS=$ROOT/builds

# 初始化仓库 (Инициализация репозитория LineageOS)
initRepos() {
    if [ ! -d $ROOT/LineageOS ]; then
        mkdir -p $ROOT/LineageOS
        cd $ROOT/LineageOS
        echo "--> Initializing LineageOS Repo"
        # ДОБАВЛЕНО --depth=1: экономит кучу места на диске GitHub Actions
        repo init -u https://github.com/LineageOS/android -b lineage-20.0 --depth=1 --git-lfs
        echo
    fi
}

# 仓库应用DogDay补丁 (Пропускаем патчи автора)
applyManifestsPatches() {
    if [ -d $ROOT/LineageOS ]; then
        cd $ROOT/LineageOS/.repo/manifests
        echo "--> Discard Manifests Changes"
        git fetch origin
        git reset --hard origin/lineage-20.0
        echo

        # Эту строчку комментируем, чтобы чужие патчи не сломали сборку blossom
        # git am $ROOT/Patches/LineageOS/manifests/*.patch
        echo
    fi
}

# 同步仓库内容 (Скачивание деревьев blossom и синхронизация)
syncRepos() {
    if [ -d $ROOT/LineageOS ]; then
        cd $ROOT/LineageOS
        
        echo "--> Cloning trees for 64-bit build (blossom)"
        # Клонируем Device Tree
        git clone https://github.com/xiaomi-blossom-dev/device_xiaomi_blossom.git -b lineage-20 device/xiaomi/blossom
        
        # Клонируем Vendor Tree (убедись, что имя репозитория совпадает у автора)
        git clone https://github.com/xiaomi-blossom-dev/vendor_xiaomi_blossom.git -b lineage-20 vendor/xiaomi/blossom
        
        # Клонируем Kernel Tree (ядро mt6765)
        git clone https://github.com/xiaomi-blossom-dev/kernel_xiaomi_mt6765.git -b lineage-20 kernel/xiaomi/blossom

        echo "--> Syncing repos"
        # ДОБАВЛЕНО --depth=1: скачивает только актуальные файлы без истории, чтобы уложиться в лимит диска
        repo sync -c --force-sync --no-clone-bundle --no-tags --depth=1 -j16
        echo
    fi
}

# applyPatches() {
#     echo "--> Applying prerequisite patches"
#     bash $BL/apply-patches.sh $BL prerequisite
#     echo

#     echo "--> Applying TrebleDroid patches"
#     bash $BL/apply-patches.sh $BL trebledroid
#     echo

#     echo "--> Applying personal patches"
#     bash $BL/apply-patches.sh $BL personal
#     echo

#     echo "--> Generating makefiles"
#     cd device/phh/treble
#     cp $BL/pe.mk .
#     bash generate.sh pe
#     cd ../../..
#     echo
# }

# 应用补丁
applyPatches() {
    cd $ROOT/Patches/LineageOS

    echo "--> Applying personal patches"
    # Device camouflage patch
    python $ROOT/Patches/apply.py $ROOT/LineageOS $ROOT/Patches/LineageOS/mask
    # Custom recovery patch
    python $ROOT/Patches/apply.py $ROOT/LineageOS $ROOT/Patches/LineageOS/custom_recovery
    echo
}

# 设置环境
setupEnv() {
    echo "--> Setting up build environment"
    cd $ROOT/LineageOS
    source build/envsetup.sh
    # mkdir -p $OUTPUTS
    echo
}

build() {
    echo "--> Building LineageOS 20 for blossom (Redmi 9C NFC 64-bit)"
    export RELEASE_TYPE=RELEASE
    
    # Конфигурация из твоего нового дерева
    lunch lineage_blossom-userdebug   
    
    croot
    mka clobber
    mka bacon -j$(nproc --all) 2>&1 | tee build.log
    echo
}

# buildVariant() {
#     echo "--> Building treble_arm64_bvN"
#     lunch treble_arm64_bvN-userdebug
#     make -j$(nproc --all) installclean
#     make -j$(nproc --all) systemimage
#     mv $OUT/system.img $BD/system-treble_arm64_bvN.img
#     echo
# }

# generateOta() {
#     echo "--> Generating OTA file"
#     version="$(date +v%Y.%m.%d)"
#     timestamp="$START"
#     json="{\"version\": \"$version\",\"date\": \"$timestamp\",\"variants\": ["
#     find $BD/ -name "PixelExperience_*" | sort | {
#         while read file; do
#             filename="$(basename $file)"
#             if [[ $filename == *"vndklite"* ]]; then
#                 name="treble_arm64_bvN-vndklite"
#             elif [[ $filename == *"slim"* ]]; then
#                 name="treble_arm64_bvN-slim"
#             else
#                 name="treble_arm64_bvN"
#             fi
#             size=$(wc -c $file | awk '{print $1}')
#             url="https://github.com/ponces/treble_build_pe/releases/download/$version/$filename"
#             json="${json} {\"name\": \"$name\",\"size\": \"$size\",\"url\": \"$url\"},"
#         done
#         json="${json%?}]}"
#         echo "$json" | jq . > $BL/ota.json
#     }
#     echo
# }

START=$(date +%s)

initRepos
# applyManifestsPatches
syncRepos
# applyPatches
setupEnv
build

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
