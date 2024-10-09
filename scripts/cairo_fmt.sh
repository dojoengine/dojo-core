#!/bin/bash

if [ "$1" == "--check" ]; then
    scarb --manifest-path crates/contracts/Scarb.toml fmt --check
else
    scarb --manifest-path crates/contracts/Scarb.toml fmt
fi
