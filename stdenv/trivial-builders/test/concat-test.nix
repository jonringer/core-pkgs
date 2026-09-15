{
  runCommand,
  concatText,
  writeText,
  patch,
  emptyFile,
}:
let
  stri = writeText "pathToTest";
  txt1 = stri "abc";
  txt2 = stri (toString patch);
  res = concatText "textToTest" [
    txt1
    txt2
  ];
in
runCommand "test-concatPaths" { } ''
  diff -U3 <(cat ${txt1} ${txt2}) ${res}
  diff -U3 ${concatText "void" [ ]} ${emptyFile}
  touch $out
''
