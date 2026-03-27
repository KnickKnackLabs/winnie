<div align="center">

# winnie

**Multiboot USB drives and QEMU VMs from [mise](https://mise.jdx.dev) tasks.**

![shell: bash](https://img.shields.io/badge/shell-bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![tasks: mise](https://img.shields.io/badge/tasks-mise-7c3aed?style=flat)](https://mise.jdx.dev)
[![vm: QEMU](https://img.shields.io/badge/vm-QEMU-ff6600?style=flat&logo=qemu&logoColor=white)](https://www.qemu.org)
[![tests: BATS](https://img.shields.io/badge/tests-BATS-blue?style=flat)](https://bats-core.readthedocs.io)

</div>

## Quick start

```bash
# Browse what's available
winnie catalog:pop-os

# Download an ISO
winnie iso:get pop-os -v 24.04 --variant generic

# Create a bootable disk image
winnie disk:format --image disk.img --size 4096 --arch x86_64
winnie disk:add ~/.local/share/winnie/isos/pop-os_*.iso --image disk.img

# Boot it
winnie vm:boot --image disk.img --uefi
```

Add more distros to the same disk with additional `disk:add` calls — GRUB is regenerated automatically.

## Flash a USB drive

```bash
# Create and populate the image
winnie disk:format --image multiboot.img --size 8192 --arch x86_64
winnie disk:add alpine.iso --image multiboot.img
winnie disk:add pop-os.iso --image multiboot.img

# Write to USB
winnie disk:flash multiboot.img --device /dev/disk4
```

> [!NOTE]
> On macOS, `disk:flash` uses the raw device (`/dev/rdisk*`) for faster writes and refuses to flash the boot disk.

## Architecture

```
┌─────────────────────────────────┐
│ CATALOG                         │
│                                 │
│ Query distro mirrors            │
│ alpine · debian · mint · pop-os │
└─────────────────────────────────┘
        │ versions, URLs, checksums
        ▼
┌────────────────────────────┐
│ ISO                        │
│                            │
│ get · add · list · extract │
│ Download, verify, store    │
└────────────────────────────┘
        │ kernel, initrd, squashfs
        ▼
┌──────────────────────────────────┐
│ DISK                             │
│                                  │
│ format · add · flash · list      │
│ Partition, GRUB, populate, write │
└──────────────────────────────────┘
        │ bootable device / image
        ▼
┌─────────────────────────────┐
│ VM                          │
│                             │
│ boot · console · screenshot │
│ stats · kill · list         │
└─────────────────────────────┘
```

## Commands

| Command | Description |
| --- | --- |
| `winnie catalog:alpine` | List available Alpine versions and variants |
| `winnie catalog:debian` | List available Debian Live versions and variants |
| `winnie catalog:mint` | List available Linux Mint versions and variants |
| `winnie catalog:pop-os` | List available Pop!_OS versions and channels |
| `winnie iso:get` | Download and verify an ISO from the catalog |
| `winnie iso:add` | Add a local ISO file to the store |
| `winnie iso:list` | List ISOs in the local store |
| `winnie iso:extract` | Extract boot files and generate a manifest |
| `winnie disk:format` | Format a device or image as a multiboot drive |
| `winnie disk:add` | Copy an ISO's boot files onto a winnie disk |
| `winnie disk:flash` | Write a disk image to a physical USB device |
| `winnie disk:list` | List distros installed on a winnie disk |
| `winnie disk:inspect` | Inspect partitions, GRUB, and distros on an image |
| `winnie grub:deploy` | Hot-reload grub.cfg onto an existing image |
| `winnie vm:boot` | Boot a disk image or ISO in QEMU |
| `winnie vm:list` | List running winnie VMs |
| `winnie vm:console` | Attach to the QEMU monitor console |
| `winnie vm:screenshot` | Capture a screenshot from a running VM |
| `winnie vm:stats` | Report VM CPU, memory, and disk I/O |
| `winnie vm:kill` | Gracefully stop a running VM |

## Supported distros

| Distro | Catalog task | Architectures |
| --- | --- | --- |
| Alpine Linux | `catalog:alpine` | x86_64, aarch64 |
| Debian | `catalog:debian` | amd64, arm64 |
| Linux Mint | `catalog:mint` | x86_64 |
| Pop!_OS | `catalog:pop-os` | amd64, arm64 |

Adding a distro means writing one catalog task that returns JSON (version, URL, checksum). The rest of the pipeline is generic.

## VM management

```bash
# Boot with hardware acceleration (hvf on macOS, kvm on Linux)
winnie vm:boot --image disk.img --uefi

# Cross-arch: boot an ARM image on an x86 host (or vice versa)
winnie vm:boot --image arm-disk.img --arch aarch64 --uefi

# Headless mode for CI/automation
winnie vm:boot --image disk.img --headless

# Monitor a running VM
winnie vm:stats                   # CPU, memory, disk I/O
winnie vm:screenshot -o boot.png  # Capture the display
winnie vm:console                 # Interactive QEMU monitor
```

## How it works

<details>
<summary><b>Disk layout</b></summary>

winnie disks use a GPT partition table with three partitions:

| # | Type | Size | Purpose |
| --- | --- | --- | --- |
| 1 | BIOS Boot | 2 MB | GRUB stage 1.5 for legacy BIOS |
| 2 | EFI System | 256 MB | FAT32, GRUB EFI bootloader |
| 3 | Data | Remaining | ext4, distro files + GRUB config |

Both BIOS and UEFI boot are supported. GRUB modules are installed for each target architecture during `disk:format`.

</details>

<details>
<summary><b>ISO extraction</b></summary>

`iso:extract` uses 7zz to pull boot files from an ISO without mounting it:

- Parses the ISO's `grub.cfg` to find the first menu entry
- Extracts the kernel, initrd, and squashfs filesystem
- Writes a `manifest.json` with boot parameters
- Strips ISO-specific boot params (`findiso=`, `iso-scan/`)

</details>

<details>
<summary><b>Cross-architecture GRUB</b></summary>

Formatting a disk for a non-native architecture (e.g., x86_64 GRUB on an arm64 host) works by extracting pre-built GRUB modules from Debian .deb packages inside a Docker container.

</details>

## Requirements

- [mise](https://mise.jdx.dev) — task runner, manages all other tool dependencies
- [Docker](https://www.docker.com) — disk formatting (partitioning, ext4, GRUB)
- [QEMU](https://www.qemu.org) — VM tasks

## Testing

```bash
mise run test
```

BATS test suite covering architecture helpers, GRUB generation, ISO extraction, and disk format routing.
