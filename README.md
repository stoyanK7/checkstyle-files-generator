# checkstyle-files-generator

`checkstyle-files-generator` is Checkstyle's build-time command-line application for
generating XML metadata and converting XDoc `.xml.template` files into generated
`.xml` pages. It is not an end-user Checkstyle distribution; it is developed alongside
the main [Checkstyle repository](https://github.com/checkstyle/checkstyle).

## Build and verify

Run:

```bash
./mvnw clean verify
```

## Developing with Checkstyle

After changing this project, install its current snapshot locally:

```bash
./mvnw clean install
```

For a local integration build, temporarily set `checkstyle-files-generator.version` in
the Checkstyle checkout's `pom.xml` to this project's version. Do not commit that
local override. Then run the usual Checkstyle
build from the `checkstyle` checkout. Checkstyle invokes this generator with
`exec-maven-plgin`. The generator jar deliberately does not bundle Checkstyle: its
runtime classpath is provided by the freshly compiled Checkstyle checkout.

Normal development is driven through the Checkstyle build rather than by invoking the
thin jar directly, because the command requires Checkstyle's build classes and dependencies.

## Releases

This repository follows the same Maven release approach as the main Checkstyle repository, using
separate **prepare** and **perform** steps.

Development versions on `main` use the `-SNAPSHOT` suffix. If the next planned release version
needs to change, run the **Bump Version** workflow first. It updates the project to the requested
`*-SNAPSHOT` version and commits the change.

To publish a release, manually run the **Release** workflow with the desired version, without
the `-SNAPSHOT` suffix. The release process:

* runs Maven `release:prepare`, which changes the POM to the release version, creates the release
  commit and Git tag, then advances `main` to the next development `-SNAPSHOT` version;
* pushes the release commits and tag to GitHub;
* runs Maven `release:perform` from the prepared release state;
* rebuilds the project from the release tag and publishes signed binary, source, and Javadoc
  artifacts to Maven Central.

The workflow does not create a GitHub Release. Publishing requires the Maven Central and GPG
secrets configured for the repository.
