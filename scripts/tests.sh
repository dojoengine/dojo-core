# Cargo testing.
cargo test -p dojo-compiler

# Testing abigen content, which also builds the core contracts.
# Need to check because the formatting of the generated code is then different from the one
# generated on the fly.
# cargo run -r --bin dojo-abigen -- --check

# Testing with the demo compiler.
cargo build -r --bin demo-compiler
./target/release/demo-compiler test --manifest-path crates/contracts/Scarb.toml
./target/release/demo-compiler test --manifest-path examples/dojo_simple/Scarb.toml
