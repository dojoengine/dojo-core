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

/!\ The commands below will work when the compiler will newly generate the artifacts /!\

```bash
# Note, use `-r` to run the binary in release mode as Scarb is very slow in debug mode.

# To generate the bindings.
cargo run -r -p dojo-abigen

# To check if the bindings are up to date.
cargo run -r -p dojo-abigen -- --check
```

## Work in progress

This repository is currently being built by extracting some parts of the [dojo](https://github.com/dojoengine/dojo) repo.

Tasks:

- [ ] Add back the artifacts and manifests generation.
- [ ] Add back all the types including `Ty` for introspection.
- [ ] [PR11](https://github.com/dojoengine/dojo-core/pull/11) to have `Event` as a new resource.
- [ ] [PR12](https://github.com/dojoengine/dojo-core/pull/12) for world events to have keys.
- [ ] Debug `2.8` panic that prevent the compiler from working with this Cairo version.
- [ ] Simplify the plugin by having the expanded code into files instead of plain strings.
- [ ] Add model extensibility (append only).
- [ ] Check if base contract can be removed to instead use a component to inject the world dispatcher.
- [ ] Check the possibility to remove warnings during compilation if the users wants to.
