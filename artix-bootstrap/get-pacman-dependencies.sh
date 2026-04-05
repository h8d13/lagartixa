#!/bin/bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Artix
set -e -u -o pipefail

shared_dependencies() {
  local EXECUTABLE=$1
  for PACKAGE in $(ldd "$EXECUTABLE" | grep "=> /" | awk '{print $3}'); do
    LC_ALL=c pacman -Qo "$PACKAGE"
  done | awk '{print $5}'
}

pkgbuild_dependencies() {
  local PKGBUILD=$1
  local EXCLUDE=$2
  # shellcheck disable=SC1090
  source "$PKGBUILD"
  # shellcheck disable=SC2154
  for DEPEND in "${depends[@]}"; do
    # shellcheck disable=SC2001
    echo "$DEPEND" | sed "s/[>=<].*$//"
  done | grep -v "$EXCLUDE"
}

# Main
{
  shared_dependencies "/usr/bin/pacman"
  pkgbuild_dependencies "$HOME/artools-workspace/artixlinux/packages/pacman/trunk/PKGBUILD" "bash"
} | sort -u | xargs
