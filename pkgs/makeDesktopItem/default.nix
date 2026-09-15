{
  lib,
  writeTextFile,
}:

# See https://specifications.freedesktop.org/desktop-entry-spec/latest/
{
  name,
  desktopName,
  exec ? null,
  icon ? null,
  comment ? null,
  genericName ? null,
  terminal ? false,
  type ? "Application",
  categories ? null,
  mimeTypes ? null,
  startupNotify ? null,
  startupWMClass ? null,
  noDisplay ? null,
  prefersNonDefaultGPU ? null,
  actions ? { },
  keywords ? null,
  extraConfig ? { },
}:

let
  # Render a boolean to "true" or "false" for .desktop file format
  boolToDesktop = b: if b then "true" else "false";

  # Render a list to a semicolon-separated string with trailing semicolon
  listToDesktop = xs: lib.concatStringsSep ";" xs + ";";

  # Render a single key-value entry, skipping null values
  optionalEntry =
    key: value:
    if value == null then
      ""
    else if builtins.isBool value then
      "${key}=${boolToDesktop value}"
    else if builtins.isList value then
      "${key}=${listToDesktop value}"
    else
      "${key}=${toString value}";

  mainEntries =
    lib.filter (s: s != "") [
      "Type=${type}"
      (optionalEntry "Name" desktopName)
      (optionalEntry "GenericName" genericName)
      (optionalEntry "Comment" comment)
      (optionalEntry "Icon" icon)
      (optionalEntry "Exec" exec)
      (optionalEntry "Terminal" terminal)
      (optionalEntry "Categories" categories)
      (optionalEntry "MimeType" mimeTypes)
      (optionalEntry "StartupNotify" startupNotify)
      (optionalEntry "StartupWMClass" startupWMClass)
      (optionalEntry "NoDisplay" noDisplay)
      (optionalEntry "PrefersNonDefaultGPU" prefersNonDefaultGPU)
      (optionalEntry "Keywords" keywords)
    ]
    ++ lib.mapAttrsToList (k: v: "${k}=${toString v}") extraConfig;

  # Render action sections
  actionNames = builtins.attrNames actions;
  actionsSections = lib.concatMapStringsSep "\n\n" (
    actionName:
    let
      action = actions.${actionName};
      entries =
        lib.filter (s: s != "") [
          (optionalEntry "Name" (action.name or actionName))
          (optionalEntry "Icon" (action.icon or null))
          (optionalEntry "Exec" (action.exec or null))
        ]
        ++ lib.mapAttrsToList (k: v: "${k}=${toString v}") (
          removeAttrs action [
            "name"
            "icon"
            "exec"
          ]
        );
    in
    "[Desktop Action ${actionName}]\n" + lib.concatStringsSep "\n" entries
  ) actionNames;

  actionsLine = if actionNames != [ ] then "Actions=${lib.concatStringsSep ";" actionNames};" else "";

  content =
    "[Desktop Entry]\n"
    + lib.concatStringsSep "\n" mainEntries
    + (lib.optionalString (actionsLine != "") "\n${actionsLine}")
    + (lib.optionalString (actionsSections != "") "\n\n${actionsSections}")
    + "\n";
in
writeTextFile {
  name = "${name}.desktop";
  destination = "/share/applications/${name}.desktop";
  text = content;
}
