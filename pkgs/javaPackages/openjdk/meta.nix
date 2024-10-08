lib: version: with lib; {
  homepage = "https://openjdk.java.net/";
  license = licenses.gpl2Only;
  description = "Open-source Java Development Kit";
  maintainers = [ ];
  platforms = [ "i686-linux" "x86_64-linux" "aarch64-linux" "armv7l-linux" "armv6l-linux" "powerpc64le-linux" ];
  mainProgram = "java";
  knownVulnerabilities = optionals (builtins.elem (versions.major version) [ "12" "13" "14" "15" "16" "18" "19" "20" ]) [
    "This OpenJDK version has reached its end of life."
  ];
}
