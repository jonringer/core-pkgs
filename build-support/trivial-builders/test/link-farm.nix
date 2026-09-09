{
  linkFarm,
  patch,
  writeTextFile,
  runCommand,
}:
let
  foo = writeTextFile {
    name = "foo";
    text = "foo";
  };

  linkFarmFromList = linkFarm "linkFarmFromList" [
    {
      name = "foo";
      path = foo;
    }
    {
      name = "patch";
      path = patch;
    }
  ];

  linkFarmWithRepeats = linkFarm "linkFarmWithRepeats" [
    {
      name = "foo";
      path = foo;
    }
    {
      name = "patch";
      path = patch;
    }
    {
      name = "foo";
      path = patch;
    }
  ];

  linkFarmFromAttrs = linkFarm "linkFarmFromAttrs" {
    inherit foo patch;
  };

  linkFarmDelimitOptionList = linkFarm "linkFarmDelimitOptionList" {
    "-foo" = foo;
    "-patch" = patch;
  };
in
runCommand "test-linkFarm" { } ''
  function assertPathEquals() {
    local a b;
    a="$(realpath "$1")"
    b="$(realpath "$2")"
    if [ "$a" != "$b" ]; then
      echo "path mismatch!"
      echo "a: $1 -> $a"
      echo "b: $2 -> $b"
      exit 1
    fi
  }

  assertPathEquals "${linkFarmFromList}/foo" "${foo}"
  assertPathEquals "${linkFarmFromList}/patch" "${patch}"

  assertPathEquals "${linkFarmWithRepeats}/foo" "${patch}"
  assertPathEquals "${linkFarmWithRepeats}/patch" "${patch}"

  assertPathEquals "${linkFarmFromAttrs}/foo" "${foo}"
  assertPathEquals "${linkFarmFromAttrs}/patch" "${patch}"

  assertPathEquals "${linkFarmDelimitOptionList}/-foo" "${foo}"
  assertPathEquals "${linkFarmDelimitOptionList}/-patch" "${patch}"

  touch $out
''
