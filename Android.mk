ifeq ($(TARGET_ARCH),x86)
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE := newinstaller
LOCAL_MODULE_TAGS := system_builder

# use squashfs for iso, unless explictly disabled
ifneq ($(USE_SQUASHFS),0)
MKSQUASHFS = $(shell which mksquashfs)

define build-squashfs-target
	$(if $(shell $(MKSQUASHFS) -version | grep "version [0-3].[0-9]"),\
		$(error Your mksquashfs is too old to work with kernel 2.6.29. Please upgrade to squashfs-tools 4.0))
	$(hide) $(MKSQUASHFS) $(1) $(2) -noappend
endef
endif

initrd_dir := $(LOCAL_PATH)/initrd
initrd_bin := \
	$(initrd_dir)/init \
	$(wildcard $(initrd_dir)/*/*)

INITRD_RAMDISK := $(PRODUCT_OUT)/initrd.img
$(INITRD_RAMDISK): $(initrd_bin) | $(ACP) $(MKBOOTFS)
	rm -rf $(TARGET_INSTALLER_OUT)
	$(ACP) -pr $(initrd_dir) $(TARGET_INSTALLER_OUT)
	ln -s /bin/ld-linux.so.2 $(TARGET_INSTALLER_OUT)/lib
	mkdir -p $(addprefix $(TARGET_INSTALLER_OUT)/,android mnt proc sys tmp sfs)
	$(MKBOOTFS) $(TARGET_INSTALLER_OUT) | gzip -9 > $@

boot_dir := $(PRODUCT_OUT)/boot
$(boot_dir): $(wildcard $(LOCAL_PATH)/boot/isolinux/*) | $(ACP)
	rm -rf $@
	$(ACP) -pr $(dir $(<D)) $@
	$(hide) sed -i "s|CMDLINE|$(BOARD_KERNEL_CMDLINE)|" $@/isolinux/isolinux.cfg

BUILT_IMG := $(addprefix $(PRODUCT_OUT)/,ramdisk.img system.$(if $(MKSQUASHFS),sfs,img) initrd.img)
BUILT_IMG += $(if $(TARGET_PREBUILT_KERNEL),$(TARGET_PREBUILT_KERNEL),$(PRODUCT_OUT)/kernel)

ISO_IMAGE := $(PRODUCT_OUT)/$(TARGET_PRODUCT).iso
$(ISO_IMAGE): $(boot_dir) $(BUILT_IMG)
	@echo ----- Making iso image ------
	$(hide) sed -i "s|DATE|`date +"%F"`|" $</isolinux/isolinux.cfg
	genisoimage -vJURT -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-input-charset utf-8 -V "Android LiveCD" -o $@ $^

ANDROID_SRC := /android-system
USB_BOOT := $(PRODUCT_OUT)/usb_boot

usb_tmp_img := $(PRODUCT_OUT)/usb_tmp.img
$(usb_tmp_img): $(BUILT_IMG) | $(MKEXT2IMG)
	rm -rf $(USB_BOOT)
	mkdir -p $(USB_BOOT)$(ANDROID_SRC)
	echo -n "$(BOARD_KERNEL_CMDLINE) SRC=$(ANDROID_SRC)" > $(USB_BOOT)/cmdline
	ln $^ $(USB_BOOT)
	mv $(USB_BOOT)/{ramdisk.img,system.*} $(USB_BOOT)$(ANDROID_SRC)
	mv $(USB_BOOT)/initrd.img $(USB_BOOT)/ramdisk
	num_blocks=`du -sk $(USB_BOOT) | tail -n1 | awk '{print $$1;}'`; \
	num_inodes=`find $(USB_BOOT) | wc -l`; \
	$(MKEXT2IMG) -d $(USB_BOOT) -b `expr $$num_blocks + 20480` -N `expr $$num_inodes + 15` -m 0 $@

USB_LAYOUT := $(LOCAL_PATH)/usb_layout.conf
USB_IMAGE := $(PRODUCT_OUT)/$(TARGET_PRODUCT)_usb.img
$(USB_IMAGE): $(usb_tmp_img) $(USB_LAYOUT) $(PRODUCT_OUT)/grub/grub.bin
	@echo ----- Making usb image ------
	@sed 's|default 2|default 0|' $(PRODUCT_OUT)/grub/grub.bin > $@
	@$(edit_mbr) -l $(USB_LAYOUT) -i $@ usb_boot=$(usb_tmp_img)

.PHONY: iso_img usb_img
iso_img: $(ISO_IMAGE)
usb_img: $(USB_IMAGE)

endif
