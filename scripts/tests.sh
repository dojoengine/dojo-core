# Cargo testing.
# To output the Cairo fix tests, use the `--fix` argument.

# Testing the dojo compiler.
cargo test -p dojo-compiler

# Testing abigen content, which also builds the core contracts.
# Need to check because the formatting of the generated code is then different from the one
# generated on the fly.
if [ "$1" == "--fix" ]; then
    cargo run -r --bin dojo-abigen
else
    cargo run -r --bin dojo-abigen -- --check
fi

# Testing with the demo compiler.
if [ "$1" == "--fix" ]; then
    CAIRO_FIX_TESTS=1 cargo build -r --bin demo-compiler
else
    cargo build -r --bin demo-compiler
fi

./target/release/demo-compiler test --manifest-path crates/contracts/Scarb.toml

./target/release/demo-compiler build --manifest-path examples/dojo_simple/Scarb.toml
./target/release/demo-compiler test --manifest-path examples/dojo_simple/Scarb.toml
