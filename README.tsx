/** @jsxImportSource jsx-md */

import { readdirSync, readFileSync } from "fs";
import { join } from "path";

import {
  Heading, Paragraph, CodeBlock,
  Bold, Code, Link,
  Badge, Badges, Center, Details, Section, Alert,
  Table, TableHead, TableRow, Cell,
  List, Item,
  Raw,
} from "readme/src/components";
import { labeledBox } from "readme/src/components";

// ── Dynamic data from the repo ────────────────────────────────────

const ROOT = import.meta.dir;
const TASKS_DIR = join(ROOT, ".mise/tasks");

// Scan mise tasks — extract name and description from task files
function scanTasks(dir: string, prefix = ""): [string, string][] {
  const entries = readdirSync(dir, { withFileTypes: true });
  const tasks: [string, string][] = [];
  for (const entry of entries) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      // Check for _default router task
      const defaultPath = join(path, "_default");
      try {
        const content = readFileSync(defaultPath, "utf-8");
        const match = content.match(/#MISE description="(.+?)"/);
        if (match) {
          const name = prefix ? `${prefix}:${entry.name}` : entry.name;
          tasks.push([name, match[1]]);
        }
      } catch {
        // No _default — recurse into non-hidden children
        tasks.push(...scanTasks(path, prefix ? `${prefix}:${entry.name}` : entry.name));
      }
    } else if (entry.name !== "_default" && !entry.name.startsWith(".")) {
      const content = readFileSync(path, "utf-8");
      const hidden = content.includes("#MISE hide=true");
      if (hidden) continue;
      const match = content.match(/#MISE description="(.+?)"/);
      if (match) {
        const name = prefix ? `${prefix}:${entry.name}` : entry.name;
        tasks.push([name, match[1]]);
      }
    }
  }
  return tasks.sort((a, b) => a[0].localeCompare(b[0]));
}

// Scan catalog tasks — each file is a distro
function scanCatalog(): { name: string; task: string }[] {
  const catalogDir = join(TASKS_DIR, "catalog");
  return readdirSync(catalogDir)
    .filter(f => !f.startsWith("."))
    .map(f => ({ name: f, task: `catalog:${f}` }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

// Count BATS tests
function countTests(): number {
  const testsDir = join(ROOT, "tests");
  try {
    return readdirSync(testsDir)
      .filter(f => f.endsWith(".bats"))
      .reduce((count, f) => {
        const content = readFileSync(join(testsDir, f), "utf-8");
        return count + (content.match(/@test /g) || []).length;
      }, 0);
  } catch { return 0; }
}

const commands = scanTasks(TASKS_DIR);
const distros = scanCatalog();
const testCount = countTests();

// ── Architecture diagram ──────────────────────────────────────────

const catalogBox = labeledBox("CATALOG", [
  `${distros.map(d => d.name).join(" · ")}`,
], undefined, { style: "unicode" });

const isoBox = labeledBox("ISO", [
  "get · add · list · extract",
], undefined, { style: "unicode" });

const diskBox = labeledBox("DISK", [
  "format · add · flash · list",
], undefined, { style: "unicode" });

const vmBox = labeledBox("VM", [
  "boot · console · screenshot",
  "stats · kill · list",
], undefined, { style: "unicode" });

const flow = [
  ...catalogBox,
  "        │",
  "        ▼",
  ...isoBox,
  "        │",
  "        ▼",
  ...diskBox,
  "        │",
  "        ▼",
  ...vmBox,
];

// ── ASCII art ─────────────────────────────────────────────────────

const art = [
  "    ┌──────────┐",
  "    │ ▓▓▓▓▓▓▓▓ │",
  "    │ ▓ GRUB ▓ │",
  "    │ ▓▓▓▓▓▓▓▓ │",
  "    │  Alpine   │",
  "    │  Debian   │",
  "    │  Pop!_OS  │",
  "    └────┬┬────┘",
  "         ││",
  "    ─────┘└─────",
].join("\n");

// ── Readme ────────────────────────────────────────────────────────

const readme = (
  <>
    <Center>
      <Raw>{`<pre>${art}</pre>\n\n`}</Raw>

      <Heading level={1}>winnie</Heading>

      <Paragraph>
        <Bold>One disk, many distros.</Bold>
      </Paragraph>

      <Badges>
        <Badge label="shell" value="bash" color="4EAA25" logo="gnubash" logoColor="white" />
        <Badge label="tasks" value="mise" color="7c3aed" href="https://mise.jdx.dev" />
        <Badge label="vm" value="QEMU" color="ff6600" logo="qemu" logoColor="white" href="https://www.qemu.org" />
        <Badge label="tests" value={`${testCount} passing`} color="blue" href="https://bats-core.readthedocs.io" />
      </Badges>
    </Center>

    <Paragraph>
      {`winnie builds multiboot USB drives and QEMU VMs from ${Link({ href: "https://mise.jdx.dev", children: "mise" })} tasks. Download distros, format a drive, add as many as you want, boot it.`}
    </Paragraph>

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
      <CodeBlock>{flow.join("\n")}</CodeBlock>
    </Section>

    <Section title={`Commands (${commands.length})`}>
      <Paragraph>
        {"Auto-discovered from "}
        <Code>.mise/tasks/</Code>
        {". "}
        <Bold>This table updates when you add or rename tasks.</Bold>
      </Paragraph>

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

    <Section title={`Supported distros (${distros.length})`}>
      <Paragraph>
        {"Auto-discovered from "}
        <Code>.mise/tasks/catalog/</Code>
        {". Each file is a distro."}
      </Paragraph>

      <Table>
        <TableHead>
          <Cell>Distro</Cell>
          <Cell>Catalog task</Cell>
        </TableHead>
        {distros.map(d => (
          <TableRow>
            <Cell>{d.name}</Cell>
            <Cell><Code>{d.task}</Code></Cell>
          </TableRow>
        ))}
      </Table>

      <Paragraph>
        Adding a distro means writing one catalog task that returns JSON
        (version, URL, checksum). The rest of the pipeline is generic.
      </Paragraph>
    </Section>

    <Section title="VM management">
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
          on an arm64 host) works by extracting pre-built GRUB modules from
          Debian .deb packages inside a Docker container.
        </Paragraph>
      </Details>
    </Section>

    <Section title="Requirements">
      <List>
        <Item>{Link({ href: "https://mise.jdx.dev", children: "mise" })} — task runner, manages all other tool dependencies</Item>
        <Item>{Link({ href: "https://www.docker.com", children: "Docker" })} — disk formatting (partitioning, ext4, GRUB)</Item>
        <Item>{Link({ href: "https://www.qemu.org", children: "QEMU" })} — VM tasks</Item>
      </List>
    </Section>

    <Section title="Testing">
      <CodeBlock lang="bash">{`mise run test`}</CodeBlock>

      <Paragraph>
        {`${testCount} tests across ${readdirSync(join(ROOT, "tests")).filter(f => f.endsWith(".bats")).length} BATS files — architecture helpers, GRUB generation, ISO extraction, disk format routing.`}
      </Paragraph>
    </Section>
  </>
);

console.log(readme);
