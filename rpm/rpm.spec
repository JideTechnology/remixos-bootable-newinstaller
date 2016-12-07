Summary: %{?title}%{!?title:Android-x86} - Run Android on your PC
Name: %{?name}%{!?name:android-x86}
Version: %{remixos_version}
Release: %{build_number}
Source1: kernel
Source2: initrd.img
Source3: ramdisk.img
Source4: %{systemimg}
License: Commercial / Apache Public License / GPLv2
Group: Operating system/Android
URL: http://www.jide.com/remixos-for-pc

%description
Remix OS for PC is based on the Android-x86 open source project which
is a porting of AOSP to x86 platform. Most components of the project
is licensed under Apache Public License 2.0. Some components are
licensed under GNU General Public License (GPL) 2.0 or later.

%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/%{install_prefix}
install -m644 %{S:1} %{S:2} %{S:3} %{S:4} %{buildroot}/%{install_prefix}
echo "ro.remixos.meta.installer=rpm:%{build_number}" >> %{buildroot}/%{install_prefix}/remixos_meta.sys


%post
. /etc/os-release
mkdir -p /%{install_prefix}/data
if [ "$ID" = "debian" -o "$ID_LIKE" = "debian" ]; then
	grubcfg=/boot/grub/custom.cfg
elif mountpoint -q /boot/efi; then
	grubcfg=/boot/efi/EFI/$ID/custom.cfg && efi=efi
else
	grubcfg=/boot/grub2/custom.cfg
fi
echo -e "menuentry \"%{?title}%{!?title:Android-x86} %{remixos_version}-%{build_number}\" {\n\tsearch --set=root --file /%{install_prefix}/kernel\n\tlinux$efi /%{install_prefix}/kernel quiet %{cmdline} \n\tinitrd$efi /%{install_prefix}/initrd.img\n}" > $grubcfg
echo -e "menuentry \"%{?title}%{!?title:Android-x86} %{remixos_version}-%{build_number} (DEBUG mode)\" {\n\tsearch --set=root --file /%{install_prefix}/kernel\n\tlinux$efi /%{install_prefix}/kernel %{cmdline} DEBUG=2\n\tinitrd$efi /%{install_prefix}/initrd.img\n}" >> $grubcfg

if [ "$ID" = "debian" -o "$ID_LIKE" = "debian" ]; then
	sed -i 's/^GRUB_HIDDEN_/#GRUB_HIDDEN_/' /etc/default/grub
	update-grub
fi

%postun
. /etc/os-release
if [ "$ID" = "debian" -o "$ID_LIKE" = "debian" ]; then
	grubcfg=/boot/grub/custom.cfg
elif mountpoint -q /boot/efi; then
	grubcfg=/boot/efi/EFI/$ID/custom.cfg
else
	grubcfg=/boot/grub2/custom.cfg
fi
if [ "$1" = "1" ]; then
	new_prefix=`dirname $(grep initrd $grubcfg | head -1 | awk '{print $2}')`
	if [ "$new_prefix" != "/%{install_prefix}" ]; then
		rmdir $new_prefix/data
		mv /%{install_prefix}/data $new_prefix
		rmdir /%{install_prefix}
	fi
else
	rmdir /%{install_prefix}/data /%{install_prefix}
	rm -f $grubcfg
fi

%clean
rm -rf %{buildroot}

%files
/%{install_prefix}/*
