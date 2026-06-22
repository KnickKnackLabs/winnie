# Contributing to winnie

`winnie` is a mise-shaped KnickKnackLabs tool: tasks live in `.mise/tasks/`, shared helpers live in `lib/`, tests live in `test/`, and `README.md` is generated from `README.tsx`.

## Local setup

```bash
gh repo clone KnickKnackLabs/winnie
cd winnie

mise trust
mise install

# Optional system tools used by VM and ISO tests.
mise run setup

mise run test
mise run doctor
```

The `setup` task installs host packages that mise cannot manage directly (QEMU, socat, mkisofs/genisoimage, and Linux disk-formatting tools when applicable).

## Validation before a PR

```bash
mise run test
codebase lint "$PWD"
readme build --check
git diff --check
```

`mise run test` runs the fast BATS suite. Slow VM interaction coverage lives under `test/integration/` and skips unless QEMU plus a cached Alpine ISO are available.

## USB safety

`disk:flash` and device-formatting commands are destructive. Always confirm the target whole-disk device (`diskutil list` on macOS, `lsblk` on Linux) immediately before running them. Do not pass a partition path when a whole disk is required.
