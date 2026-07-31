# Omybuntu release playbook

Use this playbook together with `RELEASES_AND_CHANNELS.md`. Never publish a
stable tag while its physical validation checklist is pending.

## One-time project configuration

1. Create a dedicated signing key offline and store its revocation certificate
   and backup outside the repository.
2. Add the protected GitLab CI/CD variables documented in
   `RELEASES_AND_CHANNELS.md`.
3. Protect the `v*` tag pattern and the `rc` and `master` branches in GitLab.
4. Apply equivalent branch protection to `rc` and `master` in GitHub.

## First v1.0 development build

The source `version` must contain `v1.0.0_dev1`. Commit and push the candidate
to both development remotes, then create a signed tag:

```bash
git switch dev
git push origin dev
git push gitlab dev
git tag --sign v1.0.0_dev1 --message "Omybuntu v1.0.0_dev1"
git push gitlab v1.0.0_dev1
```

Wait for the GitLab test, build, signature, and release jobs to pass. Only then
mirror the immutable tag used by installed systems:

```bash
git push origin v1.0.0_dev1
```

## First release candidate

Create `rc` from the approved development commit. Change `version` to
`v1.0.0_rc1`, commit the version change, and publish the branch before its
signed tag:

```bash
git switch -c rc dev
git push --set-upstream origin rc
git push --set-upstream gitlab rc
git tag --sign v1.0.0_rc1 --message "Omybuntu v1.0.0_rc1"
git push gitlab v1.0.0_rc1
```

After the GitLab pipeline passes, mirror the tag to GitHub and test the
published artifacts on the hardware matrix:

```bash
git push origin v1.0.0_rc1
```

For another candidate, merge the fixes from `dev`, increment the RC number in
`version`, commit, and repeat with `v1.0.0_rcN`.

## Stable v1.0.0

Complete `release/checklists/v1.0.0.md`, record evidence, replace `pending`
with `approved`, and change `version` to `v1.0.0`. Commit those release-only
changes on `rc`, then create `master` from that exact approved commit:

```bash
git switch rc
git push origin rc
git push gitlab rc
git switch -c master
git push --set-upstream gitlab master
git tag --sign v1.0.0 --message "Omybuntu v1.0.0"
git push gitlab v1.0.0
```

Wait for the stable pipeline and GitLab Release to succeed. Download and verify
the ISO, checksum, signature, and public key from a clean environment. Confirm
the live ISO reports `v1.0.0` and channel `stable`, then mirror the tag:

```bash
git push origin master
git push origin v1.0.0
```

For later stable releases, switch to the existing `master` branch and use a
fast-forward merge from the approved `rc` commit instead of creating it.

If any GitLab release pipeline fails, do not reuse or move its published tag.
Fix the problem on `dev`, increment the dev or RC number, and promote a new
signed tag.
