# Findings

## Swapping out early pieces

`elogind` was hardcoded in https://gitea.artixlinux.org/artix/artix-bootstrap/src/commit/4f1d56c7aeced69ef94434fe9e9b9bfe94f891d8/artix-bootstrap.sh#L239

There is another dep chain: `NM -> polkit -> elogind`

We got rid of it by using `dhcpd` and `iwd` directly + `seatd` and patched said file above
