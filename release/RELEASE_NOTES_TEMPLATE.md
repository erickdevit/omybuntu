# Omybuntu ${RELEASE_VERSION}

Official Omybuntu AMD64 ISO based on Ubuntu 26.04.

## Requirements

- AMD64 computer with UEFI firmware
- USB drive large enough for the ISO
- A verified backup before repartitioning or installing

## Download and verify

Download `${RELEASE_FILE}`, `${RELEASE_FILE}.sha256`,
`${RELEASE_FILE}.sig`, and `omybuntu-release-key.asc` from:

`${RELEASE_PACKAGE_URL}`

```bash
sha256sum --check ${RELEASE_FILE}.sha256
gpg --import omybuntu-release-key.asc
gpg --verify ${RELEASE_FILE}.sig ${RELEASE_FILE}
```

Release signing key fingerprint: `${RELEASE_GPG_FINGERPRINT}`

## Installation

Write the verified ISO to a USB drive, boot it in UEFI mode, and follow the
graphical installer. Back up all important data before changing disk
partitions. Installation can erase the selected disk.

## Known issues

${RELEASE_KNOWN_ISSUES}

Report new problems through the
[Omybuntu GitHub issue tracker](https://github.com/erickdevit/omybuntu/issues)
and include the release version, hardware details, installation mode, and
relevant logs.
