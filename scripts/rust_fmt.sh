#!/bin/bash

if [ "$1" == "--check" ]; then
    cargo +nightly-2024-08-28 fmt --check --all -- "$@"
else
    cargo +nightly-2024-08-28 fmt --all -- "$@"
fi
