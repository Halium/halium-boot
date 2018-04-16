#
# Copyright (C) 2014 Jolla Oy
# Copyright (C) 2017 Marius Gripsgard <marius@ubports.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

LOCAL_PATH:= $(call my-dir)
HALIUM_PATH:=$(LOCAL_PATH)

# We use the commandline and kernel configuration varables from
# build/core/Makefile to be consistent. Support for boot/recovery
# image specific kernel COMMANDLINE vars is provided but whether it
# works or not is down to your bootloader.

HALIUM_BOOTIMG_COMMANDLINE :=

# Find any fstab files for required partition information.
# in AOSP we could use TARGET_VENDOR
# TARGET_VENDOR := $(shell echo $(PRODUCT_MANUFACTURER) | tr '[:upper:]' '[:lower:]')
# but Cyanogenmod seems to use device/*/$(TARGET_DEVICE) in config.mk so we will too.
HALIUM_FSTABS := $(shell find device/*/$(TARGET_DEVICE) -name *fstab* | grep -v goldfish)
# If fstab files were not found from primary device repo then they might be in
# some other device repo so try to search for them first in device/PRODUCT_MANUFACTURER. 
# In many cases PRODUCT_MANUFACTURER is the short vendor name used in folder names.
ifeq "$(HALIUM_FSTABS)" ""
TARGET_VENDOR := "$(shell echo $(PRODUCT_MANUFACTURER) | tr '[:upper:]' '[:lower:]')"
HALIUM_FSTABS := $(shell find device/$(TARGET_VENDOR) -name *fstab* | grep -v goldfish)
endif
# Some devices devices have the short vendor name in PRODUCT_BRAND so try to
# search from device/PRODUCT_BRAND if fstab files are still not found.
ifeq "$(HALIUM_FSTABS)" ""
TARGET_VENDOR := "$(shell echo $(PRODUCT_BRAND) | tr '[:upper:]' '[:lower:]')"
HALIUM_FSTABS := $(shell find device/$(TARGET_VENDOR) -name *fstab* | grep -v goldfish)
endif

ifneq ($(strip $(TARGET_NO_KERNEL)),true)
  INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel
else
  INSTALLED_KERNEL_TARGET :=
endif

HALIUM_BOOTIMAGE_ARGS := \
	$(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET)) \
	--kernel $(INSTALLED_KERNEL_TARGET)

ifeq ($(BOARD_KERNEL_SEPARATED_DT),true)
  INSTALLED_DTIMAGE_TARGET := $(PRODUCT_OUT)/dt.img
  HALIUM_BOOTIMAGE_ARGS += --dt $(INSTALLED_DTIMAGE_TARGET)
  BOOTIMAGE_EXTRA_DEPS := $(INSTALLED_DTIMAGE_TARGET)
endif

ifdef BOARD_KERNEL_BASE
  HALIUM_BOOTIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif

ifdef BOARD_KERNEL_PAGESIZE
  HALIUM_BOOTIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif

# Strip lead/trail " from broken BOARD_KERNEL_CMDLINEs :(
HALIUM_BOARD_KERNEL_CMDLINE := $(shell echo '$(BOARD_KERNEL_CMDLINE)' | sed -e 's/^"//' -e 's/"$$//')

ifneq "" "$(strip $(HALIUM_BOARD_KERNEL_CMDLINE) $(HALIUM_BOOTIMG_COMMANDLINE))"
  HALIUM_BOOTIMAGE_ARGS += --cmdline "$(strip $(HALIUM_BOARD_KERNEL_CMDLINE) $(HALIUM_BOOTIMG_COMMANDLINE))"
endif


include $(CLEAR_VARS)
LOCAL_MODULE:= halium-boot
# Here we'd normally include $(BUILD_SHARED_LIBRARY) or something
# but nothing seems suitable for making an img like this
LOCAL_MODULE_CLASS := ROOT
LOCAL_MODULE_SUFFIX := .img
LOCAL_MODULE_PATH := $(PRODUCT_OUT)

include $(BUILD_SYSTEM)/base_rules.mk
HALIUM_BOOT_INTERMEDIATE := $(call intermediates-dir-for,ROOT,$(LOCAL_MODULE),)

.PHONY: HALIUM_BOOT_RAMDISK
HALIUM_BOOT_RAMDISK := $(HALIUM_BOOT_INTERMEDIATE)/halium-initramfs.gz
GET_INITRD := $(LOCAL_PATH)/get-initrd.sh

$(LOCAL_BUILT_MODULE): $(INSTALLED_KERNEL_TARGET) $(HALIUM_BOOT_RAMDISK) $(BOOTIMAGE_EXTRA_DEPS)
	@echo "Making halium-boot.img in $(dir $@) using $(INSTALLED_KERNEL_TARGET) $(HALIUM_BOOT_RAMDISK)"
	@mkdir -p $(dir $@)
	@rm -rf $@
ifeq ($(BOARD_CUSTOM_MKBOOTIMG),pack_intel)
	$(MKBOOTIMG) $(DEVICE_BASE_BOOT_IMAGE) $(INSTALLED_KERNEL_TARGET) $(HALIUM_BOOT_RAMDISK) $(cmdline) $@
else
	@mkbootimg --ramdisk $(HALIUM_BOOT_RAMDISK) $(HALIUM_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
endif
ifdef BOOT_RAMDISK_SEANDROIDENFORCE
	@echo -n "SEANDROIDENFORCE" >> $@
endif

$(HALIUM_BOOT_RAMDISK):
	@mkdir -p $(dir $@)
	@echo "Downloading initramfs to : $@"
ifdef BOARD_USE_LOCAL_INITRD
	@echo "Using local initramfs at device/*/$(TARGET_DEVICE)/initramfs.gz"
	@cp device/*/$(TARGET_DEVICE)/initramfs.gz $@
else
	@$(GET_INITRD) ${TARGET_ARCH} $@
endif

.PHONY: halium-common

halium-boot: mkbootimg

halium-common: bootimage halium-boot
