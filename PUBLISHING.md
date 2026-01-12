# Publishing `htzbuild` to npm

Follow these steps whenever you publish a new version so downstream projects can keep using the CLI via `npm install -g htzbuild`.

1. **Prepare the release**
   - Update `package.json`/`package-lock.json` version numbers (`npm version patch|minor|major`) and push the accompanying commit.
   - Verify the `name`, `bin`, `files`, and `engines` entries still reflect the CLI (`htzbuild`), and double-check `README.md`, `cloud-init-builder.yaml`, and other artifacts are in the package.
   - Run any smoke checks you need (e.g., `node ./bin/htzbuild --help`) before publishing.

2. **Authenticate with npm**
   - Log in using `npm login` (or `npm adduser` for CI) and ensure you have publish rights for the `htzbuild` package.
   - Confirm your session with `npm whoami`.

3. **Publish**
   - Publish the package with `npm publish --access public`.
   - If you are using a Git tag for releases, create one like `git tag vX.Y.Z` and push it alongside `git push --follow-tags`.

4. **Post-publish**
   - Run `npm view htzbuild version` to confirm the registry reports the new version.
   - Update documentation or release notes if necessary, then notify consumers (e.g., via GitHub release, Slack, etc.).

5. **Rolling back (if needed)**
   - If the publish fails or you discover an issue, immediately publish an updated version (you cannot unpublish a public version without waiting). Increment the patch/minor version and rerun `npm publish`.

Keep `PUBLISHING.md` up to date if your CI workflow changes or if you start supporting scoped registries.

