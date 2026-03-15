# weiner-toy

Clean Ventoy replacement for Linux. Uses standard GRUB2 + bash to create multiboot USB drives. No binary blobs.

## How It Works

User formats a USB drive (`mise run format -d /dev/sdX`), drops ISO files into `/isos/` on the data partition, and boots. GRUB2 auto-detects distros at boot time by checking for marker directories inside each ISO (e.g., `/casper/` for Ubuntu, `/live/` for Debian Live, `/arch/` for Arch).

## Structure

- `grub/grub.cfg` — The boot-time auto-detection engine. This is the core of the project.
- `.mise/tasks/format` — Partitions USB and installs GRUB for both UEFI and Legacy BIOS.
- `.mise/tasks/add` — Convenience task to copy ISOs to the USB.
- `.mise/tasks/list` — Shows ISOs on a weiner-toy USB with detected distro families.

## Platform Constraint

The `format` task requires Linux (grub-install, sgdisk, mkfs). Development can happen on macOS but testing requires Linux or a VM.

## Adding Distro Support

To add a new distro family, add a detection block in `grub/grub.cfg`. You need:
1. A marker file path that uniquely identifies the distro (e.g., `/casper/vmlinuz`)
2. The kernel and initrd paths inside the ISO
3. The boot parameters the distro's initramfs expects for ISO loopback booting

Check the distro's wiki or existing GLIM configs for reference.
