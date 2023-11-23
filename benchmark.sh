#!/usr/bin/env bash

if [[ ! -v IN_BENCHMARK_SHELL ]]; then
    cd "${BASH_SOURCE[0]%/*}"
    exec nix develop -c bash benchmark.sh "$@"
fi

# A simple NixOS system
read -d '' sys1 <<EOF || :
(import "$nixpkgs/nixos" {
  configuration = { pkgs, lib, ... }: with lib; {
    services.xserver.enable = true;
  };
}).vm
EOF

read -d '' drv1 <<EOF || :
with import <nixpkgs> { config = {}; };
writeText "txt" "a"
EOF

export sys1 drv1

export parseArgs='nix=$1; expr=$2; shift; shift'
oldBuild() {
    eval "$parseArgs"
    "$nix"/nix-build --no-out-link -E "$expr" "$@"
}
newBuild() {
    eval "$parseArgs"
    "$nix"/nix build --experimental-features nix-command --impure --expr "$expr" --no-link "$@"
}
instantiateEval() {
    eval "$parseArgs"
    "$nix"/nix-instantiate --eval -E "($expr).outPath" "$@"
}
instantiateEvalRW() {
    instantiateEval "$@" --read-write-mode
}
nixEval() {
    eval "$parseArgs"
    "$nix"/nix eval --experimental-features nix-command --impure --expr "($expr).outPath" "$@"
}
nixEvalReadOnly() {
    nixEval "$@" --read-only
}
instantiate() {
    eval "$parseArgs"
    "$nix"/nix-instantiate -E "$expr" "$@"
}
export -f instantiateEval instantiateEvalRW nixEval nixEvalReadOnly oldBuild newBuild instantiate

benchmark() {
    hyperfine --warmup 2 --min-runs 3 "$@"
    echo
}
benchmarkn() {
    runs=$1
    shift
    hyperfine --warmup 2 --min-runs $runs "$@"
    echo
}

#--------------------------------------------------

daemon_store_vs_local_store() {
    export localStore=/tmp/nix-benchmark-store
    clearStore() { chmod -R +w $localStore 2>/dev/null; rm -rf $localStore; }
    clearStore
    benchmark \
        'instantiateEval $nix_2_7 "$sys1"' \
        'instantiate $nix_2_7 "$sys1"' \
        'instantiate $nix_2_7 "$sys1" --store $localStore'
    clearStore
}
# 'instantiateEval $nix_2_7 "$sys1"' ran
#   1.16 ± 0.03 times faster than 'instantiate $nix_2_7 "$sys1" --store $localStore'
#   1.51 ± 0.08 times faster than 'instantiate $nix_2_7 "$sys1"'

instantiate_eval_2_3_vs_2_7() {
    benchmark \
        'instantiateEval $nix_2_3 "$sys1"' \
        'instantiateEval $nix_2_7 "$sys1"'
}
# 'instantiateEval $nix_2_7 "$sys1"' ran
#   1.14 ± 0.04 times faster than 'instantiateEval $nix_2_3 "$sys1"'

instantiate_2_3_vs_2_7() {
    benchmark \
        'instantiate $nix_2_3 "$sys1"' \
        'instantiate $nix_2_7 "$sys1"'
}
# 'instantiate $nix_2_3 "$sys1"' ran
#   1.02 ± 0.02 times faster than 'instantiate $nix_2_7 "$sys1"'

nix_eval_vs_instantiate_eval() {
    benchmark \
        'instantiateEval $nix_2_7 "$sys1"' \
        'nixEval $nix_2_7 "$sys1"'
}
# 'instantiateEval $nix_2_7 "$sys1"' ran
#   1.38 ± 0.04 times faster than 'nixEval $nix_2_7 "$sys1"'

# Latest nix version as of 2023-11
nix_2_18() {
    benchmark \
        'instantiateEval $nix_2_3 "$sys1"' \
        'instantiateEvalRW $nix_2_3 "$sys1"' \
        'nixEvalReadOnly $nix_2_18 "$sys1"' \
        'nixEval $nix_2_18 "$sys1"'
}

# Benchmark 1: instantiateEval $nix_2_3 "$sys1"
#   Time (mean ± σ):      5.093 s ±  0.142 s    [User: 5.132 s, System: 0.585 s]
#   Range (min … max):    4.997 s …  5.256 s    3 runs

# Benchmark 2: instantiateEvalRW $nix_2_3 "$sys1"
#   Time (mean ± σ):      5.543 s ±  0.084 s    [User: 4.948 s, System: 0.811 s]
#   Range (min … max):    5.450 s …  5.611 s    3 runs

# Benchmark 3: nixEvalReadOnly $nix_2_18 "$sys1"
#   Time (mean ± σ):      4.309 s ±  0.022 s    [User: 3.816 s, System: 0.483 s]
#   Range (min … max):    4.293 s …  4.334 s    3 runs

# Benchmark 4: nixEval $nix_2_18 "$sys1"
#   Time (mean ± σ):      5.408 s ±  0.006 s    [User: 3.133 s, System: 1.806 s]
#   Range (min … max):    5.402 s …  5.414 s    3 runs

# Summary
#   nixEvalReadOnly $nix_2_18 "$sys1" ran
#     1.18 ± 0.03 times faster than instantiateEval $nix_2_3 "$sys1"
#     1.26 ± 0.01 times faster than nixEval $nix_2_18 "$sys1"
#     1.29 ± 0.02 times faster than instantiateEvalRW $nix_2_3 "$sys1"

#--------------------------------------------------
# Run many benchmarks

run_all() {
    # run daemon_store_vs_local_store
    run instantiate_eval_2_3_vs_2_7
    run instantiate_2_3_vs_2_7
    run nix_eval_vs_instantiate_eval
}

run() {
    echo "$@"
    echo "----------------------------------"
    "$@"
    echo
}

# Run args
"$@"
