#
# Copyright (C) 2014 The Android-x86 Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#

ifeq ($(KBUILD_OUTPUT),)
ifeq ($(TARGET_PREBUILT_KERNEL),)

KERNEL_DIR ?= kernel

ifneq ($(filter x86%,$(TARGET_ARCH)),)
TARGET_KERNEL_ARCH ?= $(TARGET_ARCH)
KERNEL_TARGET := bzImage
TARGET_KERNEL_CONFIG ?= android-$(TARGET_KERNEL_ARCH)_defconfig
KERNEL_CONFIG_DIR := arch/x86/configs
endif
ifeq ($(TARGET_ARCH),arm)
KERNEL_TARGET := zImage
TARGET_KERNEL_CONFIG ?= goldfish_defconfig
KERNEL_CONFIG_DIR := arch/arm/configs
endif

KBUILD_OUTPUT := $(abspath $(TARGET_OUT_INTERMEDIATES)/kernel)
mk_kernel := + $(hide) $(MAKE) -C $(KERNEL_DIR) O=$(KBUILD_OUTPUT) ARCH=$(TARGET_ARCH) CROSS_COMPILE=$(abspath $(TARGET_TOOLS_PREFIX)) $(if $(SHOW_COMMANDS),V=1)

KERNEL_CONFIG_FILE := $(if $(wildcard $(TARGET_KERNEL_CONFIG)),$(TARGET_KERNEL_CONFIG),$(KERNEL_DIR)/$(KERNEL_CONFIG_DIR)/$(TARGET_KERNEL_CONFIG))

MOD_ENABLED := $(shell grep ^CONFIG_MODULES=y $(KERNEL_CONFIG_FILE))
FIRMWARE_ENABLED := $(shell grep ^CONFIG_FIRMWARE_IN_KERNEL=y $(KERNEL_CONFIG_FILE))

# I understand Android build system discourage to use submake,
# but I don't want to write a complex Android.mk to build kernel.
# This is the simplest way I can think.
KERNEL_DOTCONFIG_FILE := $(KBUILD_OUTPUT)/.config
KERNEL_ARCH_CHANGED := $(if $(filter 0,$(shell grep -s ^$(if $(filter x86,$(TARGET_KERNEL_ARCH)),\#.)CONFIG_64BIT $(KERNEL_DOTCONFIG_FILE) | wc -l)),FORCE)
$(KERNEL_DOTCONFIG_FILE): $(KERNEL_CONFIG_FILE) $(wildcard $(TARGET_KERNEL_DIFFCONFIG)) $(KERNEL_ARCH_CHANGED)
	$(hide) mkdir -p $(@D) && cat $(wildcard $^) > $@
	$(mk_kernel) oldnoconfig

# bison is needed to build kernel and external modules from source
BISON := $(HOST_OUT_EXECUTABLES)/bison$(HOST_EXECUTABLE_SUFFIX)

BUILT_KERNEL_TARGET := $(KBUILD_OUTPUT)/arch/$(TARGET_ARCH)/boot/$(KERNEL_TARGET)
$(INSTALLED_KERNEL_TARGET): $(KERNEL_DOTCONFIG_FILE) | $(ACP) $(BISON)
	$(mk_kernel) $(KERNEL_TARGET) $(if $(MOD_ENABLED),modules)
	$(hide) $(ACP) -fp $(BUILT_KERNEL_TARGET) $@
	$(if $(FIRMWARE_ENABLED),$(mk_kernel) INSTALL_MOD_PATH=$(abspath $(TARGET_OUT)) firmware_install)

ifneq ($(MOD_ENABLED),)
KERNEL_MODULES_DEP := $(firstword $(wildcard $(TARGET_OUT)/lib/modules/*/modules.dep))
KERNEL_MODULES_DEP := $(if $(KERNEL_MODULES_DEP),$(KERNEL_MODULES_DEP),$(TARGET_OUT)/lib/modules)

$(TARGET_OUT_INTERMEDIATES)/%.kmodule: $(INSTALLED_KERNEL_TARGET)
	$(hide) cp -an $(EXTRA_KERNEL_MODULE_PATH_$*) $(TARGET_OUT_INTERMEDIATES)/$*.kmodule
	@echo Building additional kernel module $*
	$(mk_kernel) M=$(abspath $@) modules

$(KERNEL_MODULES_DEP): $(INSTALLED_KERNEL_TARGET) $(patsubst %,$(TARGET_OUT_INTERMEDIATES)/%.kmodule,$(TARGET_EXTRA_KERNEL_MODULES))
	$(hide) rm -rf $(TARGET_OUT)/lib/modules
	$(mk_kernel) INSTALL_MOD_PATH=$(abspath $(TARGET_OUT)) modules_install
	+ $(hide) for kmod in $(TARGET_EXTRA_KERNEL_MODULES) ; do \
		echo Installing additional kernel module $${kmod} ; \
		$(subst +,,$(subst $(hide),,$(mk_kernel))) INSTALL_MOD_PATH=$(abspath $(TARGET_OUT)) M=$(abspath $(TARGET_OUT_INTERMEDIATES))/$${kmod}.kmodule modules_install ; \
	done
	$(hide) rm -f $(TARGET_OUT)/lib/modules/*/{build,source}
endif

$(BUILT_SYSTEMIMAGE): $(KERNEL_MODULES_DEP)

# rules to get source of Broadcom 802.11a/b/g/n hybrid device driver
# based on broadcomsetup.sh of Kyle Evans
WL_PATH := $(KERNEL_DIR)/drivers/net/wireless/wl
-include $(WL_PATH)/build.mk

installclean: FILES += $(KBUILD_OUTPUT) $(INSTALLED_KERNEL_TARGET)

TARGET_PREBUILT_KERNEL := $(INSTALLED_KERNEL_TARGET)

.PHONY: kernel $(if $(KERNEL_ARCH_CHANGED),$(KERNEL_HEADERS_COMMON)/linux/binder.h)
kernel: $(TARGET_PREBUILT_KERNEL)

else

$(INSTALLED_KERNEL_TARGET): $(TARGET_PREBUILT_KERNEL) | $(ACP)
	$(copy-file-to-new-target)
ifdef TARGET_PREBUILT_MODULES
	mkdir -p $(TARGET_OUT)/lib
	$(hide) cp -r $(TARGET_PREBUILT_MODULES) $(TARGET_OUT)/lib
endif

endif # TARGET_PREBUILT_KERNEL
endif # KBUILD_OUTPUT
