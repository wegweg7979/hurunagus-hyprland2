#!/usr/bin/env python3
"""Resolve Omarchy's Arch package list to Fedora RPM names.

The package lists and the fedora.toml map are copied verbatim from Omedora
(https://github.com/AndrewGaspar/omedora). This helper applies the same map
semantics at image-build time:

  * unknown names fall through to the same name on Fedora;
  * ``source = "dnf"`` entries use their ``names`` (or the Arch name);
  * ``source = "skip"`` entries are omitted;
  * ``source = "flathub"`` entries are omitted (Flatpaks are handled by
    /usr/share/ublue-os/flatpaks/system-flatpaks.list on first boot);
  * ``source = "copr"`` entries are emitted as packages and their COPR is
    written to --copr-out so the build can enable it;
  * ``since`` / ``until`` entries are filtered against the target Fedora
    release;
  * ``satisfied_by`` entries are omitted when one of the listed RPMs is
    already installed (e.g. podman-docker instead of moby-engine).

Only ``--fedora-version`` (or /etc/os-release), the map, and optional package
lists are read. The output is a newline-separated list of RPM names.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path


def target_fedora_version(explicit: int | None) -> int:
    if explicit is not None:
        return explicit
    for variable in ("OMEDORA_FEDORA_VERSION", "FEDORA_VERSION"):
        value = os.environ.get(variable)
        if value:
            return int(value)
    os_release = Path("/etc/os-release")
    values: dict[str, str] = {}
    for line in os_release.read_text().splitlines():
        if "=" in line:
            key, raw = line.split("=", 1)
            values[key] = raw.strip().strip('"')
    if "VERSION_ID" not in values:
        raise SystemExit("cannot determine Fedora VERSION_ID from /etc/os-release")
    return int(values["VERSION_ID"])


def entry_applies(entry: dict, fedora_version: int) -> bool:
    since = entry.get("since")
    until = entry.get("until")
    if since is not None and fedora_version < int(since):
        return False
    if until is not None and fedora_version >= int(until):
        return False
    return True


def rpm_installed(name: str) -> bool:
    if shutil.which("rpm") is None:
        return False
    return (
        subprocess.run(
            ["rpm", "-q", name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def read_package_list(path: Path):
    for raw in path.read_text().splitlines():
        package = raw.split("#", 1)[0].strip()
        if package:
            yield package


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "lists",
        nargs="+",
        type=Path,
        help="package lists to resolve (one Arch package per line)",
    )
    parser.add_argument(
        "--map",
        type=Path,
        default=Path("/ctx/fedora.toml"),
        help="path to fedora.toml (default: /ctx/fedora.toml)",
    )
    parser.add_argument(
        "--fedora-version",
        type=int,
        default=None,
        help="target Fedora release (default: VERSION_ID from /etc/os-release)",
    )
    parser.add_argument(
        "--copr-out",
        type=Path,
        default=None,
        help="write the COPR repositories referenced by the map here",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="report every skipped package on stderr",
    )
    args = parser.parse_args(argv)

    fedora_version = target_fedora_version(args.fedora_version)
    with args.map.open("rb") as handle:
        package_map: dict[str, dict] = tomllib.load(handle)

    packages: list[str] = []
    seen: set[str] = set()
    coprs: list[str] = []

    for list_path in args.lists:
        for package in read_package_list(list_path):
            entry = package_map.get(package)

            if entry is not None and not entry_applies(entry, fedora_version):
                if args.verbose:
                    print(
                        f"skip (does not apply to Fedora {fedora_version}): {package}",
                        file=sys.stderr,
                    )
                continue

            if entry is None:
                source = "dnf"
                names = [package]
                satisfied_by: list[str] = []
            else:
                source = str(entry.get("source", "dnf"))
                names = [str(name) for name in entry.get("names", [package])]
                satisfied_by = [str(name) for name in entry.get("satisfied_by", [])]

            if source == "skip":
                if args.verbose:
                    print(f"skip ({entry.get('reason', 'no reason given')}): {package}", file=sys.stderr)
                continue
            if source == "flathub":
                if args.verbose:
                    print(f"skip (Flathub: {entry.get('app_id', '?')}): {package}", file=sys.stderr)
                continue
            if source == "copr":
                copr = str(entry.get("copr", "")).strip()
                if copr and copr not in coprs:
                    coprs.append(copr)
            elif source != "dnf":
                print(f"unknown package source {source!r} for {package}", file=sys.stderr)
                return 2

            if satisfied_by and any(rpm_installed(name) for name in satisfied_by):
                if args.verbose:
                    print(
                        f"skip (already satisfied by {', '.join(satisfied_by)}): {package}",
                        file=sys.stderr,
                    )
                continue

            for name in names:
                if name and name not in seen:
                    seen.add(name)
                    packages.append(name)

    if packages:
        sys.stdout.write("\n".join(packages) + "\n")
    if args.copr_out is not None:
        args.copr_out.write_text("\n".join(coprs) + ("\n" if coprs else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
