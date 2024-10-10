# Cargo testing.
# To output the Cairo fix tests, use the `--fix` argument.

# Testing the dojo compiler.
cargo build -r --workspace

# Testing with the demo compiler.
if [ "$1" == "--fix" ]; then
    CAIRO_FIX_TESTS=1 cargo test -p dojo-compiler
else
    cargo test -p dojo-compiler
fi

# Testing abigen content, which also builds the core contracts.
# Need to check because the formatting of the generated code is then different from the one
# generated on the fly.
if [ "$1" == "--fix" ]; then
    ./target/release/dojo-abigen
    ./scripts/rust_fmt.sh
else
    ./target/release/dojo-abigen --check
fi

./target/release/demo-compiler test --manifest-path crates/contracts/Scarb.toml

./target/release/demo-compiler build --manifest-path examples/dojo_simple/Scarb.toml
./target/release/demo-compiler test --manifest-path examples/dojo_simple/Scarb.toml
