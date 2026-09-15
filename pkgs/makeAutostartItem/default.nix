{
  lib,
  runCommand,
}:

# Creates an XDG autostart entry by copying a .desktop file from a package.
# See https://specifications.freedesktop.org/autostart-spec/latest/
{
  name,
  package,
  srcEntry ? "${package}/share/applications/${name}.desktop",
}:

runCommand "${name}-autostart" { } ''
  mkdir -p $out/etc/xdg/autostart
  cp "${srcEntry}" $out/etc/xdg/autostart/${name}.desktop
''
