/** @jsxImportSource jsx-md */

import {
  Heading, Paragraph, CodeBlock, HR,
  Bold, Code, Link, Image,
  Badge, Badges, Center, Details, Section, Alert,
  Table, TableHead, TableRow, Cell,
  List, Item,
  Raw,
} from "readme/src/components";
import { box, labeledBox, sideBySide } from "readme/src/components";

// ── Data ──────────────────────────────────────────────────────────

const distros = [
  { name: "Alpine Linux", task: "catalog:alpine", archs: "x86_64, aarch64" },
  { name: "Debian",       task: "catalog:debian",  archs: "amd64, arm64" },
  { name: "Linux Mint",   task: "catalog:mint",    archs: "x86_64" },
  { name: "Pop!_OS",      task: "catalog:pop-os",  archs: "amd64, arm64" },
];

const commands: [string, string][] = [
  // catalog
  ["catalog:alpine",  "List available Alpine versions and variants"],
  ["catalog:debian",  "List available Debian Live versions and variants"],
  ["catalog:mint",    "List available Linux Mint versions and variants"],
  ["catalog:pop-os",  "List available Pop!_OS versions and channels"],
  // iso
  ["iso:get",         "Download and verify an ISO from the catalog"],
  ["iso:add",         "Add a local ISO file to the store"],
  ["iso:list",        "List ISOs in the local store"],
  ["iso:extract",     "Extract boot files and generate a manifest"],
  // disk
  ["disk:format",     "Format a device or image as a multiboot drive"],
  ["disk:add",        "Copy an ISO's boot files onto a winnie disk"],
  ["disk:flash",      "Write a disk image to a physical USB device"],
  ["disk:list",       "List distros installed on a winnie disk"],
  ["disk:inspect",    "Inspect partitions, GRUB, and distros on an image"],
  // grub
  ["grub:deploy",     "Hot-reload grub.cfg onto an existing image"],
  // vm
  ["vm:boot",         "Boot a disk image or ISO in QEMU"],
  ["vm:list",         "List running winnie VMs"],
  ["vm:console",      "Attach to the QEMU monitor console"],
  ["vm:screenshot",   "Capture a screenshot from a running VM"],
  ["vm:stats",        "Report VM CPU, memory, and disk I/O"],
  ["vm:kill",         "Gracefully stop a running VM"],
];

// ── Architecture diagram ──────────────────────────────────────────

const catalog = labeledBox("CATALOG", [
  "Query distro mirrors",
  "alpine · debian · mint · pop-os",
], undefined, { style: "unicode" });

const iso = labeledBox("ISO", [
  "get · add · list · extract",
  "Download, verify, store",
], undefined, { style: "unicode" });

const disk = labeledBox("DISK", [
  "format · add · flash · list",
  "Partition, GRUB, populate, write",
], undefined, { style: "unicode" });

const vm = labeledBox("VM", [
  "boot · console · screenshot",
  "stats · kill · list",
], undefined, { style: "unicode" });

const flow = [
  ...catalog,
  "        │ versions, URLs, checksums",
  "        ▼",
  ...iso,
  "        │ kernel, initrd, squashfs",
  "        ▼",
  ...disk,
  "        │ bootable device / image",
  "        ▼",
  ...vm,
];

// ── Readme ────────────────────────────────────────────────────────

const readme = (
  <>
    <Center>
      <Heading level={1}>winnie</Heading>

      <Paragraph>
        <Bold>Multiboot USB drives and VMs from composable tasks.</Bold>
      </Paragraph>

      <Paragraph>
        Download distros. Build bootable drives. Test in QEMU.{"\n"}
        Like {Link({ href: "https://ventoy.net", children: "Ventoy" })}, but built from {Link({ href: "https://mise.jdx.dev", children: "mise" })} tasks you can read, modify, and extend.
      </Paragraph>

      <Badges>
        <Badge label="shell" value="bash" color="4EAA25" logo="gnubash" logoColor="white" />
        <Badge label="tasks" value="mise" color="7c3aed" href="https://mise.jdx.dev" />
        <Badge label="vm" value="QEMU" color="ff6600" logo="qemu" logoColor="white" href="https://www.qemu.org" />
        <Badge label="tests" value="BATS" color="blue" href="https://bats-core.readthedocs.io" />
      </Badges>
    </Center>

    <Section title="Quick start">
      <CodeBlock lang="bash">{`# Browse what's available
winnie catalog:pop-os

# Download an ISO
winnie iso:get pop-os -v 24.04 --variant generic

# Create a bootable disk image
winnie disk:format --image disk.img --size 4096 --arch x86_64
winnie disk:add ~/.local/share/winnie/isos/pop-os_*.iso --image disk.img

# Boot it
winnie vm:boot --image disk.img --uefi`}</CodeBlock>

      <Paragraph>
        Add more distros to the same disk with additional{" "}
        <Code>disk:add</Code> calls — GRUB is regenerated automatically.
      </Paragraph>
    </Section>

    <Section title="Flash a USB drive">
      <CodeBlock lang="bash">{`# Create and populate the image
winnie disk:format --image multiboot.img --size 8192 --arch x86_64
winnie disk:add alpine.iso --image multiboot.img
winnie disk:add pop-os.iso --image multiboot.img

# Write to USB
winnie disk:flash multiboot.img --device /dev/disk4`}</CodeBlock>

      <Alert type="NOTE">
        {"On macOS, "}
        <Code>disk:flash</Code>
        {" uses the raw device ("}
        <Code>/dev/rdisk*</Code>
        {") for faster writes and refuses to flash the boot disk."}
      </Alert>
    </Section>

    <Section title="Architecture">
      <Paragraph>
        Four subsystems, each a group of mise tasks. Data flows down — catalog
        feeds ISO management, which feeds disk building, which feeds VM testing.
      </Paragraph>

      <CodeBlock>{flow.join("\n")}</CodeBlock>
    </Section>

    <Section title="Commands">
      <Table>
        <TableHead>
          <Cell>Command</Cell>
          <Cell>Description</Cell>
        </TableHead>
        {commands.map(([cmd, desc]) => (
          <TableRow>
            <Cell><Code>{`winnie ${cmd}`}</Code></Cell>
            <Cell>{desc}</Cell>
          </TableRow>
        ))}
      </Table>
    </Section>

    <Section title="Supported distros">
      <Table>
        <TableHead>
          <Cell>Distro</Cell>
          <Cell>Catalog task</Cell>
          <Cell>Architectures</Cell>
        </TableHead>
        {distros.map(d => (
          <TableRow>
            <Cell>{d.name}</Cell>
            <Cell><Code>{d.task}</Code></Cell>
            <Cell>{d.archs}</Cell>
          </TableRow>
        ))}
      </Table>

      <Paragraph>
        Adding a new distro means writing a catalog task that returns JSON
        (version, URL, checksum) — the rest of the pipeline is generic.
      </Paragraph>
    </Section>

    <Section title="VM management">
      <Paragraph>
        winnie wraps QEMU with automatic acceleration and cross-architecture support.
      </Paragraph>

      <CodeBlock lang="bash">{`# Boot with hardware acceleration (hvf on macOS, kvm on Linux)
winnie vm:boot --image disk.img --uefi

# Cross-arch: boot an ARM image on an x86 host (or vice versa)
winnie vm:boot --image arm-disk.img --arch aarch64 --uefi

# Headless mode for CI/automation
winnie vm:boot --image disk.img --headless

# Monitor a running VM
winnie vm:stats                   # CPU, memory, disk I/O
winnie vm:screenshot -o boot.png  # Capture the display
winnie vm:console                 # Interactive QEMU monitor`}</CodeBlock>
    </Section>

    <Section title="How it works">
      <Details summary="Disk layout">
        <Paragraph>
          winnie disks use a GPT partition table with three partitions:
        </Paragraph>

        <Table>
          <TableHead>
            <Cell>#</Cell>
            <Cell>Type</Cell>
            <Cell>Size</Cell>
            <Cell>Purpose</Cell>
          </TableHead>
          <TableRow>
            <Cell>1</Cell>
            <Cell>BIOS Boot</Cell>
            <Cell>2 MB</Cell>
            <Cell>GRUB stage 1.5 for legacy BIOS</Cell>
          </TableRow>
          <TableRow>
            <Cell>2</Cell>
            <Cell>EFI System</Cell>
            <Cell>256 MB</Cell>
            <Cell>FAT32, GRUB EFI bootloader</Cell>
          </TableRow>
          <TableRow>
            <Cell>3</Cell>
            <Cell>Data</Cell>
            <Cell>Remaining</Cell>
            <Cell>ext4, distro files + GRUB config</Cell>
          </TableRow>
        </Table>

        <Paragraph>
          Both BIOS and UEFI boot are supported. GRUB modules are installed
          for each target architecture during{" "}
          <Code>disk:format</Code>.
        </Paragraph>
      </Details>

      <Details summary="ISO extraction">
        <Paragraph>
          <Code>iso:extract</Code> uses 7zz to pull boot files from an ISO
          without mounting it:
        </Paragraph>

        <List>
          <Item>Parses the ISO's <Code>grub.cfg</Code> to find the first menu entry</Item>
          <Item>Extracts the kernel, initrd, and squashfs filesystem</Item>
          <Item>Writes a <Code>manifest.json</Code> with boot parameters</Item>
          <Item>Strips ISO-specific boot params (<Code>findiso=</Code>, <Code>iso-scan/</Code>)</Item>
        </List>
      </Details>

      <Details summary="Cross-architecture GRUB">
        <Paragraph>
          Formatting a disk for a non-native architecture (e.g., x86_64 GRUB
          on an arm64 host) is handled by extracting GRUB modules from
          Debian .deb packages inside a Docker container. No cross-compilation
          required — the modules are pre-built, winnie just needs to place them.
        </Paragraph>
      </Details>
    </Section>

    <Section title="Requirements">
      <List>
        <Item>{Link({ href: "https://mise.jdx.dev", children: "mise" })} — task runner (installs all other tools automatically)</Item>
        <Item>{Link({ href: "https://www.docker.com", children: "Docker" })} — used for disk formatting (partitioning, ext4, GRUB install)</Item>
        <Item>{Link({ href: "https://www.qemu.org", children: "QEMU" })} — VM tasks (<Code>brew install qemu</Code> / <Code>apt install qemu-system</Code>)</Item>
      </List>

      <Paragraph>
        All other dependencies (bats, gum, jq, 7zip, etc.) are managed by mise
        and installed on first run.
      </Paragraph>
    </Section>

    <Section title="Testing">
      <CodeBlock lang="bash">{`mise run test`}</CodeBlock>

      <Paragraph>
        BATS test suite covering architecture helpers, GRUB generation,
        ISO extraction, and disk format routing.
      </Paragraph>
    </Section>
  </>
);

console.log(readme);
