# AgentScript

**The Agent Oriented Programming Language**

An agentic-first programming language: TypeScript-flavored syntax, structured
parallelism with the `~` operator family, region-based memory (no GC in the
language model), compile-time tensor shapes, and constrained syntax
extensibility that stays machine-readable. The compiler, `ags`, is written in
Go.

```ts
scope {
  const users =~ api.getUsers();      // =~ spawns a concurrent task
  const posts =~ api.getPosts();
  const [u, p] = join(users, posts);  // structured join
}                                     // nothing outlives the scope
```

Every task spawned inside a `scope` is joined or cancelled before the closing
brace returns. A task escaping its scope is a *compile* error, not a runtime
bug you find later.

## What this repository is

This is the **release mirror**: prebuilt `ags` binaries and their checksums,
nothing else. The compiler is developed in a separate, private repository, so
there is no source tree here and no issue tracker for the language itself.

Two consequences worth stating plainly:

- **Tags here mark releases, not source.** A `v0.2.0` tag points at the commit
  in *this* repository that was current when that release was published. It is
  not a source tag and cannot be built from.
- **Every file here is built elsewhere and uploaded deliberately.** There is no
  CI in this repository and nothing in it runs on a server. `install.sh` runs on
  *your* machine.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/rmoralesthompson/agentscript/main/install.sh | sh
```

That downloads the binary for your platform, **verifies it against the
release's `SHA256SUMS` and refuses to install if it does not match**, and puts
it in `~/.local/bin`. It never uses `sudo` and writes nothing outside the
install directory — so a system-wide `AGS_INSTALL_DIR` like `/usr/local/bin`
only works if you can already write there.

| variable | default | |
|---|---|---|
| `AGS_VERSION` | the latest release | pin a version, e.g. `0.2.0` |
| `AGS_INSTALL_DIR` | `~/.local/bin` | where the binary lands — must be writable by you |

```sh
curl -fsSL .../install.sh | AGS_VERSION=0.2.0 AGS_INSTALL_DIR="$HOME/bin" sh
```

To install without piping a script into a shell, use the manual path below.

### By hand

Download the asset for your platform from the
[latest release](../../releases/latest), along with `SHA256SUMS`. Assets are
named `ags-<version>-<os>-<arch>`:

| platform | `<os>-<arch>` |
|---|---|
| macOS, Apple silicon | `darwin-arm64` |
| macOS, Intel | `darwin-amd64` |
| Linux, x86-64 | `linux-amd64` |
| Linux, arm64 | `linux-arm64` |

```sh
VERSION=0.2.0            # the release you downloaded
ASSET=ags-$VERSION-darwin-arm64

grep "$ASSET" SHA256SUMS | shasum -a 256 -c -
#    -> ags-0.2.0-darwin-arm64: OK

chmod +x "$ASSET"
mv "$ASSET" /usr/local/bin/ags
ags version
```

`SHA256SUMS` covers every platform's binary, so checking it whole will report
the files you did not download as missing. The `grep` above checks only yours.

**On macOS, a browser download will not run.** macOS flags files downloaded by
a browser with `com.apple.quarantine`, and these builds are not notarized, so
Gatekeeper refuses them with "cannot be opened because the developer cannot be
verified". Clear the attribute:

```sh
xattr -d com.apple.quarantine /usr/local/bin/ags
```

This does not apply to `install.sh` — `curl` does not set that attribute, so a
scripted install has nothing to clear.

### Requirements

The default backend is **self-contained** — no toolchain, no runtime, no
dependencies. `ags run` and `ags build` work from the downloaded binary alone.

The optional native backend (`--target=native`) shells out to a system `clang`
and is **opt-in**; the default backend is the complete reference and native
currently supports a subset of it. You do not need `clang` unless you ask for
`--target=native`.

## Hello, concurrency

AgentScript's hello-world is concurrent. Save this as `hello.agent`:

```ts
import std.io;

fn fetchUsers() -> []string @effects(net) {
  return ["ada", "grace", "edsger"];
}

fn fetchPosts() -> []string @effects(net) {
  return ["regions beat gc", "shapes belong in types"];
}

fn main() @effects(net) {
  scope {
    const users =~ fetchUsers();          // spawns a task, runs now
    const posts =~ fetchPosts();          // concurrent with users
    const [u, p] = join(users, posts);    // wait for both
    io.println("users: " + str(u));
    io.println("posts: " + str(p));
  }                                       // nothing outlives this brace
}
```

```sh
ags run hello.agent
```

```
users: [ada grace edsger]
posts: [regions beat gc shapes belong in types]
```

## Versions

`ags version` prints two numbers, and they move independently:

- the **compiler** version — the `ags` binary itself. A bugfix release does not
  change the language.
- the **language/spec** version — the syntax and semantics a *program* depends
  on.

Both stay on `0.x` until the language reaches 1.0. On `0.x`, expect breaking
changes between releases.

## License

[Apache License 2.0](LICENSE).

The installed binary carries the license with it — `ags license` prints it in
full, so you have the terms whether or not you ever visit this page.
