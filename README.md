# Dojo core library.

This repository contains the contracts and associated tooling for Dojo.

It includes the following crates:

* `contracts`: the core contracts and logic for Dojo written in Cairo.
* `types`: the Rust types related to the core contracts.
* `compiler`: the Cairo compiler plugin for Dojo that generates the artifacts for the contracts and associated dojo manifests.

Some binaries are also included:

* `abigen`: a program that generates the Rust bindings for the contracts, which are written into the `types` crate.
* `demo-compiler`: a demo compiler that can `build`, `test` and `clean` a Dojo project.

## Use the demo compiler.

To not have to work with sozo, the demo compiler can be used to compile the contracts.
The primary goal of the demo compiler is to compile and test the dojo core contracts.

```bash
cargo run -r -p demo-compiler build --manifest-path crates/contracts/Scarb.toml
cargo run -r -p demo-compiler test --manifest-path crates/contracts/Scarb.toml
cargo run -r -p demo-compiler clean --manifest-path crates/contracts/Scarb.toml
```

You can also compiles the examples by using the demo compiler, adjusting the path to the example `Scarb.toml` file.

## Abigen

Using [cainome](https://github.com/cartridge-gg/cainome) to generate the bindings from the Cairo ABI, the bindings must be maintained up to date with the contracts.

```bash
# Note, use `-r` to run the binary in release mode as Scarb is very slow in debug mode.

# To generate the bindings.
cargo run -r -p dojo-abigen

# To check if the bindings are up to date.
cargo run -r -p dojo-abigen -- --check
```

At the moment, after running the abigen, you must run the `cargo fmt` to fix the formatting of the generated bindings.
Please use the following script to format the code:
```bash
./scripts/rust_fmt.sh
```

## Examples

The examples folders are here to test the compiler support and showcase the features.

* `dojo_simple`: showcase a simple dojo project without any external dependencies.
* `workspace`: showcase a dojo project with multiple crates.

## Contributing

When working on `dojo-core`, consider the following:

### Devcontainer
You can use the dev-container available on [github](https://github.com/dojoengine/dojo-core/pkgs/container/dojo-core-dev) to avoid installing all the dependencies locally.

The devcontainer is also used in the CI pipeline. The devcontainer is built with `bookworm` as the base image, which should also work on Apple Silicon.

You can re-build locally if necessary on a Apple Silicon machine using:
```bash
cd .devcontainer
sudo docker build --build-arg VARIANT=bookworm .
```

### Modifying rust code
When rust code is modified, please ensure you're formatting the code correctly running those scripts:
```bash
./scripts/rust_fmt.sh
./scripts/clippy.sh
./scripts/docs.sh
```

### Modifying Cairo code

When Cairo code is modified, please ensure you're formatting:
```bash
./scripts/cairo_fmt.sh
```

If you have changed the Cairo code, you will want to run the test script to fix the Cairo changes into the test. **Please VERIFY the changes when running with --fix.**

```bash
# PLEASE VERIFY THE GENERATED CODE IS CORRECT
./scripts/tests.sh --fix
```

### Testing

To run the test suite that is used in the CI pipeline, you can run the following script:
```bash
./scripts/tests.sh
```
