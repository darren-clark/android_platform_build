
ifndef prebuilt_bundle_once
prebuilt_bundle_once := true

include $(BUILD_MULTI_PREBUILT)

#
# $(1): filepath to read, stripping it upon return
#
define _read_metadata
  $(strip $(shell cat $(1) 2> /dev/null))
endef

#
# $(1): $(LOCAL_PATH)
# $(3): module/bundle
#
define auto-prebuilt-bundle-boilerplate
  $(eval base := $(1)/$(2))
  $(eval is_host := $(call _read_metadata,$(base)/is_host))
  $(eval module_class := $(call _read_metadata,$(base)/class))
  $(eval module_tags := $(call _read_metadata,$(base)/tags))
  $(eval path_override := $(call _read_metadata,$(base)/override_path))
  $(eval module_suffix := $(call _read_metadata,$(base)/suffix))
  $(if $(ifeq $(path_override),), \
    $(if $(ifeq $(module_class,SHARED_LIBRARIES)), \
      $(eval path_override := $($(if $(prebuilt_is_host),HOST,TARGET)_OUT_INTERMEDIATE_LIBRARIES))) \
    )
  $(if $(ifeq $(module_class),STATIC), \
    $(eval uninstallable := true), \
    $(eval uninstallable := ) \
  )
  $(if $(ifeq $(module_class,JAVA_LIBRARIES)), \
    $(eval stem := javalib.jar),\
    $(eval stem := ) \
  )

  $(call auto-prebuilt-boilerplate, \
    $(notdir $(2)):$(2)/payload$(module_suffix), \
    $(is_host), \
    $(module_class), \
    $(module_tags), \
    $(path_override), \
    $(uninstallable), \
    $(stem), \
    , \
    $(PREBUILT.$(2).LOCAL_PATH), \
    $(PREBUILT.$(2).LOCAL_CERTIFICATE) \
  )
endef

endif

ifeq ($(BUNDLE_TARGETS),)
  BUNDLE_TARGETS := $(shell find $(LOCAL_PATH)/ -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
endif
ifneq ($(TARGET_BOARD_PLATFORM),)
  $(foreach t,$(BUNDLE_TARGETS), \
    $(eval $(call auto-prebuilt-bundle-boilerplate,$(LOCAL_PATH),$(t))) \
  )
else
  $(warning ** Prebuilt machinery relies on TARGET_BOARD_PLATFORM being non-null)
  $(warning *  Since its value is null, will disable prebuilts installation for:)
  $(warning *  module(s): $(BUNDLE_TARGETS))
  $(warning *  path: $(LOCAL_PATH))
  $(warning * )
  $(warning *  A quick fix might be enclosing the parent Android.mk inclusion between)
  $(warning *   ifneq ($$(TARGET_BOARD_PLATFORM),))
  $(warning *   ...)
  $(warning *   endif)
  $(warning ** )
endif
BUNDLE_TARGETS :=
