# AsNeeded signing repair

Verified October 27, 2026, after explicit maintainer approval for signing setup repair. This is release infrastructure work; it adds no app feature and does not replace the already-approved TestFlight 309 artifact.

## Cause and correction

Default distribution signing selected an identity stored in a temporary keychain belonging to another project. Its password was unrelated to the Mac login password. Removing the approved stale search-list entry was insufficient. Another temporary keychain appeared during the repair and Xcode again selected the shared certificate. Those other signing assets were left intact.

Created a dedicated Apple Distribution identity for AsNeeded in the normal login keychain, plus matching App Store profiles for the existing app, widget and Watch bundle identifiers. No certificates were revoked, bundle identifiers/capabilities changed, keychain files deleted, or access controls relaxed. No passwords or private-key contents were read by the agent. The newly generated temporary private-key file was imported with default protections and removed after the login identity was verified.

The verified local ExportOptions configuration pins the new certificate and matching profiles. It lives outside Git in the current user's Library. The optional `scripts/export-testflight.sh` helper uses that project-specific configuration, or an `ASNEEDED_EXPORT_OPTIONS` override. It never changes keychain lookup, creates assets, reads passwords, uploads, or silently replaces an existing output. Development builds and CI do not depend on the helper.

## Verification

- Direct export using the dedicated identity: `EXPORT SUCCEEDED`.
- A second export through the helper and persistent local configuration: `EXPORT SUCCEEDED`.
- Exported app signatures pass deep/strict verification; extracted public signer fingerprint matches the new identity verified in login.
- Temporary private-key file confirmed absent. Existing keys/profiles preserved.
- `bash -n scripts/export-testflight.sh` and its help smoke check pass.
- The existing TestFlight 1.2.0(309) rollout remains approved for all four tester groups. No duplicate build was uploaded.

## Future exports

```bash
./scripts/export-testflight.sh /path/to/AsNeeded.xcarchive /path/to/new-output.ipa
```

On another Mac, configure its own signing identity/profiles and set `ASNEEDED_EXPORT_OPTIONS` to its local plist. Do not commit machine-specific signing assets or configuration. If the optional asc CLI is unavailable, Xcode's archive export supports the same local ExportOptions plist.

A stale prompt naming the other project's keychain can be cancelled; it is not the credential required by this AsNeeded export path. No global guarantee is made about signing processes launched by other projects.
