<div align="center">

<pre>    ┌──────────┐
    │ ▓▓▓▓▓▓▓▓ │
    │ ▓ GRUB ▓ │
    │ ▓▓▓▓▓▓▓▓ │
    │  Alpine   │
    │  Debian   │
    │  Pop!_OS  │
    └────┬┬────┘
         ││
    ─────┘└─────</pre>

# winnie

**One disk, many distros.**

![shell: bash](https://img.shields.io/badge/shell-bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![tasks: mise](https://img.shields.io/badge/tasks-mise-7c3aed?style=flat)](https://mise.jdx.dev)
[![vm: QEMU](https://img.shields.io/badge/vm-QEMU-ff6600?style=flat&logo=qemu&logoColor=white)](https://www.qemu.org)
[![tests: 134 passing](https://img.shields.io/badge/tests-134%20passing-blue?style=flat)](https://bats-core.readthedocs.io)

</div>

winnie builds multiboot USB drives and QEMU VMs from [mise](https://mise.jdx.dev) tasks. Download distros, format a drive, add as many as you want, boot it.

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
│ alpine · debian · mint · pop-os │
└─────────────────────────────────┘
        │
        ▼
┌────────────────────────────┐
│ ISO                        │
│                            │
│ get · add · list · extract │
└────────────────────────────┘
        │
        ▼
┌─────────────────────────────┐
│ DISK                        │
│                             │
│ format · add · flash · list │
└─────────────────────────────┘
        │
        ▼
┌─────────────────────────────┐
│ VM                          │
│                             │
│ boot · console · screenshot │
│ stats · kill · list         │
└─────────────────────────────┘
```

## Commands (22)

Auto-discovered from `.mise/tasks/`. **This table updates when you add or rename tasks.**

| Command | Description |
| --- | --- |
| `winnie catalog:alpine` | Show available Alpine Linux versions and variants |
| `winnie catalog:debian` | Show available Debian Live versions and variants |
| `winnie catalog:mint` | Show available Linux Mint versions and variants |
| `winnie catalog:pop-os` | Show available Pop!_OS versions and variants |
| `winnie disk:add` | Copy an ISO file onto a winnie disk |
| `winnie disk:flash` | Write a winnie disk image to a physical device |
| `winnie disk:format` | Format a device or image as a winnie multiboot drive |
| `winnie disk:inspect` | Inspect a winnie disk image (partitions, GRUB files, ISOs) |
| `winnie disk:list` | List distros on a winnie disk |
| `winnie grub:deploy` | Deploy latest grub.cfg to an existing disk image (fast iteration) |
| `winnie iso:add` | Add a local ISO file to the store |
| `winnie iso:extract` | Extract boot files from an ISO and write a manifest |
| `winnie iso:get` | Download and verify an ISO from the catalog |
| `winnie iso:list` | List ISOs in the local store |
| `winnie setup` | Install system dependencies not available via mise |
| `winnie test` | Run all tests |
| `winnie vm:boot` | Boot a winnie disk image in QEMU |
| `winnie vm:console` | Attach to the QEMU monitor console of a running winnie VM |
| `winnie vm:kill` | Stop a running winnie VM |
| `winnie vm:list` | List running winnie VMs |
| `winnie vm:screenshot` | Capture a screenshot from a running winnie VM |
| `winnie vm:stats` | Report resource usage for a running winnie VM |

## Supported distros (4)

Auto-discovered from `.mise/tasks/catalog/`. Each file is a distro.

| Distro | Catalog task |
| --- | --- |
| alpine | `catalog:alpine` |
| debian | `catalog:debian` |
| mint | `catalog:mint` |
| pop-os | `catalog:pop-os` |

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

134 tests across 10 BATS files — architecture helpers, GRUB generation, ISO extraction, disk format routing.
