ifeq ($(TARGET_ARCH),x86)
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE := newinstaller
LOCAL_MODULE_TAGS := system_builder

define build-squashfs-target
	$(if $(shell $(MKSQUASHFS) -version | grep "version [0-3].[0-9]"),\
		$(error Your mksquashfs is too old to work with kernel 2.6.29. Please upgrade to squashfs-tools 4.0))
	$(hide) $(MKSQUASHFS) $(1) $(2) -noappend
endef

initrd_dir := $(LOCAL_PATH)/initrd
initrd_bin := \
	$(initrd_dir)/init \
	$(wildcard $(initrd_dir)/*/*)

installer_ramdisk := $(PRODUCT_OUT)/initrd.img
$(installer_ramdisk): $(initrd_bin) | $(ACP) $(MKBOOTFS)
	rm -rf $(TARGET_INSTALLER_OUT)
	$(ACP) -pr $(initrd_dir) $(TARGET_INSTALLER_OUT)
	ln -s /bin/ld-linux.so.2 $(TARGET_INSTALLER_OUT)/lib
	mkdir -p $(addprefix $(TARGET_INSTALLER_OUT)/,android mnt proc sys tmp sfs)
	$(MKBOOTFS) $(TARGET_INSTALLER_OUT) | gzip -9 > $@

boot_dir := $(LOCAL_PATH)/boot
boot_bin := $(wildcard $(boot_dir)/isolinux/*)

BUILT_IMG := $(addprefix $(PRODUCT_OUT)/,ramdisk.img system.img initrd.img)
BUILT_IMG += $(if $(TARGET_PREBUILT_KERNEL),$(TARGET_PREBUILT_KERNEL),$(PRODUCT_OUT)/kernel)

ISO_IMAGE := $(PRODUCT_OUT)/$(TARGET_PRODUCT).iso
$(ISO_IMAGE): $(BUILT_IMG) $(boot_bin)
	@echo ----- Making iso image ------
	genisoimage -vJURT -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-input-charset utf-8 -V "Android LiveCD" -o $@ \
		$(boot_dir) $(BUILT_IMG)

.PHONY: iso_img
iso_img: $(ISO_IMAGE)

# use squashfs for iso, unless explictly disabled
ifneq ($(USE_SQUASHFS),0)
iso_img: MKSQUASHFS = $(shell which mksquashfs)
endif

endif
