{
  lib,
  runCommandLocal,
  # Test targets
  writeClosure,
  samples,
}:
runCommandLocal "test-trivial-builders-writeClosure-union"
  {
    closures = lib.mapAttrs (n: v: writeClosure [ v ]) samples;
    collectiveClosure = writeClosure (lib.attrValues samples);
    inherit samples;
  }
  ''
    set -eu -o pipefail
    echo >&2 Testing mixed closures...
    echo >&2 Checking all samples "(''${samples[*]})" "$collectiveClosure"
    diff -U3 \
      <(sort <"$collectiveClosure") \
      <(cat "''${closures[@]}" | sort | uniq)
    touch "$out"
  ''
