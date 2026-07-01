# Findings

## Swapping out early pieces

`elogind` was hardcoded in [official bootstrap](https://gitea.artixlinux.org/artix/artix-bootstrap/src/commit/4f1d56c7aeced69ef94434fe9e9b9bfe94f891d8/artix-bootstrap.sh#L239)

Patch was simply to pin:

```bash
244 +  install_packages "$ARCH" "$DEST" "${SEAT_MGR}-${INIT}" # pin init-logind provider before base resolves it
245    install_packages "$ARCH" "$DEST" "base ${INIT}" # removed elogind to give choice ie seatd
```

This code simply did not exist in artix-bootstrap meaning `elogind` was always being pulled in eitherway. So I added a `-s` flag for seat managers.

There is a cool concept in the FOSS-OS (yes that's a lot of acronyms that look too similar) world.

Which I've come to name the 'leftovers'. This in it's essence is anything left in a file to rot somewhere because it's needed as part of a tool-chain or because it needs to "just work".
But essentially this is often hidden documentation that can get annoying to figure out.

The importance here is order of operations since we cannot do selections in a one shot isntaller.
So seat manager needs to come before anything else has a chance to try to need `elogind` or when `<pkg>-init` sidecars are pulled in.

## Swapping out later pieces

There is another dep chain: `NM -> elogind`
Got rid of it by using `dhcpd` and `iwd` directly + `seatd` and patched said file above
