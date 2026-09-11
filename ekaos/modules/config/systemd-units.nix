# Systemd unit and session variable options
#
# Provides the systemd.* and environment.sessionVariables options
# consumed by desktop environment modules. The systemd service
# manager translates these into unit files under /etc/systemd/.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.systemd;

  # Type for systemd unit configuration (serviceConfig, socketConfig, etc.)
  unitConfigType = types.attrsOf (
    types.oneOf [
      types.str
      types.int
      types.bool
      types.path
      types.package
    ]
  );

  # Type for a systemd service unit
  serviceOptions = {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable this service.";
      };

      description = mkOption {
        type = types.str;
        default = "";
        description = "Service description.";
      };

      after = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Units that must start before this service.";
      };

      before = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Units that must start after this service.";
      };

      wants = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Units wanted by this service.";
      };

      requires = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Units required by this service.";
      };

      bindsTo = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Units this service binds to.";
      };

      conflicts = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Units that conflict with this service.";
      };

      wantedBy = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Targets that want this service.";
      };

      requiredBy = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Targets that require this service.";
      };

      restartIfChanged = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to restart on configuration change.";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Environment variables for this service.";
      };

      path = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Packages to add to the service PATH.";
      };

      script = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Shell script to run as ExecStart.";
      };

      serviceConfig = mkOption {
        type = unitConfigType;
        default = { };
        description = "Systemd [Service] section options.";
      };
    };
  };

  # Type for a systemd socket unit
  socketOptions = {
    options = {
      description = mkOption {
        type = types.str;
        default = "";
        description = "Socket description.";
      };

      wantedBy = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Targets that want this socket.";
      };

      listenStreams = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Stream socket addresses to listen on.";
      };

      socketConfig = mkOption {
        type = unitConfigType;
        default = { };
        description = "Systemd [Socket] section options.";
      };
    };
  };

  # Type for a systemd target unit
  targetOptions = {
    options = {
      description = mkOption {
        type = types.str;
        default = "";
        description = "Target description.";
      };

      wants = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Units wanted by this target.";
      };

      requires = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Units required by this target.";
      };

      after = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Units that must start before this target.";
      };
    };
  };

  # Type for a systemd timer unit
  timerOptions = {
    options = {
      description = mkOption {
        type = types.str;
        default = "";
        description = "Timer description.";
      };

      wantedBy = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Targets that want this timer.";
      };

      timerConfig = mkOption {
        type = unitConfigType;
        default = { };
        description = "Systemd [Timer] section options.";
      };
    };
  };

  # Session variable value type — accepts string or list of strings
  sessionVarType = types.either types.str (types.listOf types.str);

  # Generate a systemd service unit file from the service attrset
  mkServiceUnit =
    name: svc:
    let
      execStart =
        if svc.script != null then
          "${pkgs.writeShellScript name svc.script}"
        else
          svc.serviceConfig.ExecStart or "";
      envLines = mapAttrsToList (k: v: "Environment=\"${k}=${v}\"") svc.environment;
      pathStr = optionalString (svc.path != [ ]) (
        "Environment=\"PATH=${concatMapStringsSep ":" (p: "${p}/bin") svc.path}:$PATH\""
      );
    in
    pkgs.writeText "${name}.service" ''
      [Unit]
      ${optionalString (svc.description != "") "Description=${svc.description}"}
      ${concatMapStringsSep "\n" (d: "After=${d}") svc.after}
      ${concatMapStringsSep "\n" (d: "Before=${d}") svc.before}
      ${concatMapStringsSep "\n" (d: "Wants=${d}") svc.wants}
      ${concatMapStringsSep "\n" (d: "Requires=${d}") svc.requires}
      ${concatMapStringsSep "\n" (d: "BindsTo=${d}") svc.bindsTo}
      ${concatMapStringsSep "\n" (d: "Conflicts=${d}") svc.conflicts}

      [Service]
      ${optionalString (svc.script != null) "ExecStart=${execStart}"}
      ${concatStringsSep "\n" (
        mapAttrsToList (k: v: "${k}=${toString v}") (
          removeAttrs svc.serviceConfig [ "ExecStart" ]
          // optionalAttrs (svc.script == null && svc.serviceConfig ? ExecStart) {
            ExecStart = svc.serviceConfig.ExecStart;
          }
        )
      )}
      ${concatStringsSep "\n" envLines}
      ${pathStr}

      [Install]
      ${concatMapStringsSep "\n" (t: "WantedBy=${t}") svc.wantedBy}
      ${concatMapStringsSep "\n" (t: "RequiredBy=${t}") svc.requiredBy}
    '';

  # Generate a systemd socket unit file
  mkSocketUnit =
    name: sock:
    pkgs.writeText "${name}.socket" ''
      [Unit]
      ${optionalString (sock.description != "") "Description=${sock.description}"}

      [Socket]
      ${concatMapStringsSep "\n" (s: "ListenStream=${s}") sock.listenStreams}
      ${concatStringsSep "\n" (mapAttrsToList (k: v: "${k}=${toString v}") sock.socketConfig)}

      [Install]
      ${concatMapStringsSep "\n" (t: "WantedBy=${t}") sock.wantedBy}
    '';

  # Generate a systemd target drop-in for wants/requires
  mkTargetDropIn =
    name: tgt:
    pkgs.writeText "${name}.conf" ''
      [Unit]
      ${optionalString (tgt.description != "") "Description=${tgt.description}"}
      ${concatMapStringsSep "\n" (u: "Wants=${u}") tgt.wants}
      ${concatMapStringsSep "\n" (u: "Requires=${u}") tgt.requires}
      ${concatMapStringsSep "\n" (u: "After=${u}") tgt.after}
    '';

  # Generate a systemd timer unit file
  mkTimerUnit =
    name: tmr:
    pkgs.writeText "${name}.timer" ''
      [Unit]
      ${optionalString (tmr.description != "") "Description=${tmr.description}"}

      [Timer]
      ${concatStringsSep "\n" (mapAttrsToList (k: v: "${k}=${toString v}") tmr.timerConfig)}

      [Install]
      ${concatMapStringsSep "\n" (t: "WantedBy=${t}") tmr.wantedBy}
    '';

  # Filter to enabled services
  enabledSystemServices = filterAttrs (_: svc: svc.enable) cfg.services;
  enabledUserServices = filterAttrs (_: svc: svc.enable) cfg.user.services;

in

{
  options = {
    # Alias for systemd.defaultTarget (used by some ekapkgs modules)
    systemd.defaultUnit = mkOption {
      type = types.str;
      default = config.systemd.defaultTarget;
      description = "Alias for systemd.defaultTarget.";
    };

    # Packages that ship systemd unit files to be installed
    systemd.packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = ''
        Packages whose systemd unit files are installed to /etc/systemd/.
        Unit files are discovered from lib/systemd/system/ and
        lib/systemd/user/ within each package.
      '';
    };

    # System services
    systemd.services = mkOption {
      type = types.attrsOf (types.submodule serviceOptions);
      default = { };
      description = "Systemd system service definitions.";
    };

    # Timers
    systemd.timers = mkOption {
      type = types.attrsOf (types.submodule timerOptions);
      default = { };
      description = "Systemd timer definitions.";
    };

    # Tmpfiles
    systemd.tmpfiles = {
      packages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Packages whose tmpfiles.d configuration should be installed.";
      };

      settings = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Tmpfiles settings (name -> rule attrsets).";
      };
    };

    # User services, sockets, and targets
    systemd.user = {
      services = mkOption {
        type = types.attrsOf (types.submodule serviceOptions);
        default = { };
        description = "Systemd user service definitions.";
      };

      sockets = mkOption {
        type = types.attrsOf (types.submodule socketOptions);
        default = { };
        description = "Systemd user socket definitions.";
      };

      targets = mkOption {
        type = types.attrsOf (types.submodule targetOptions);
        default = { };
        description = "Systemd user target definitions (drop-ins).";
      };
    };

    # Session environment variables (set in user sessions via systemd environment.d)
    environment.sessionVariables = mkOption {
      type = types.attrsOf sessionVarType;
      default = { };
      example = literalExpression ''
        {
          EDITOR = "vim";
          GIO_EXTRA_MODULES = [ "''${pkgs.glib-networking}/lib/gio/modules" ];
        }
      '';
      description = ''
        Environment variables set in user login sessions.
        Values can be strings or lists of strings (joined with `:` as separator).
      '';
    };
  };

  config = {
    # Sync defaultUnit → defaultTarget
    systemd.defaultTarget = mkDefault cfg.defaultUnit;

    # Install unit files from systemd.packages
    environment.etc = mkMerge [
      # System units from packages
      (listToAttrs (
        concatMap (
          pkg:
          let
            unitDir = "${pkg}/lib/systemd/system";
          in
          optional (builtins.pathExists unitDir) (
            nameValuePair "systemd/system-packages/${pkg.name}" {
              source = unitDir;
            }
          )
        ) cfg.packages
      ))

      # User units from packages
      (listToAttrs (
        concatMap (
          pkg:
          let
            unitDir = "${pkg}/lib/systemd/user";
          in
          optional (builtins.pathExists unitDir) (
            nameValuePair "systemd/user-packages/${pkg.name}" {
              source = unitDir;
            }
          )
        ) cfg.packages
      ))

      # Tmpfiles from packages
      (listToAttrs (
        concatMap (
          pkg:
          let
            tmpfilesDir = "${pkg}/lib/tmpfiles.d";
          in
          optional (builtins.pathExists tmpfilesDir) (
            nameValuePair "tmpfiles.d/${pkg.name}" {
              source = tmpfilesDir;
            }
          )
        ) cfg.tmpfiles.packages
      ))

      # Generated system service units
      (listToAttrs (
        mapAttrsToList (
          name: svc:
          nameValuePair "systemd/system/${name}.service" {
            source = mkServiceUnit name svc;
          }
        ) enabledSystemServices
      ))

      # Generated system timer units
      (listToAttrs (
        mapAttrsToList (
          name: tmr:
          nameValuePair "systemd/system/${name}.timer" {
            source = mkTimerUnit name tmr;
          }
        ) cfg.timers
      ))

      # Generated user service units
      (listToAttrs (
        mapAttrsToList (
          name: svc:
          nameValuePair "systemd/user/${name}.service" {
            source = mkServiceUnit name svc;
          }
        ) enabledUserServices
      ))

      # Generated user socket units
      (listToAttrs (
        mapAttrsToList (
          name: sock:
          nameValuePair "systemd/user/${name}.socket" {
            source = mkSocketUnit name sock;
          }
        ) cfg.user.sockets
      ))

      # Generated user target drop-ins
      (listToAttrs (
        mapAttrsToList (
          name: tgt:
          nameValuePair "systemd/user/${name}.target.d/ekaos.conf" {
            source = mkTargetDropIn name tgt;
          }
        ) cfg.user.targets
      ))

      # Session variables via environment.d
      (mkIf (config.environment.sessionVariables != { }) {
        "environment.d/50-ekaos.conf".text = concatStringsSep "\n" (
          mapAttrsToList (
            name: value:
            let
              strValue = if isList value then concatStringsSep ":" value else toString value;
            in
            "${name}=${strValue}"
          ) config.environment.sessionVariables
        );
      })
    ];

    # Activation script to link package unit files
    system.activationScripts.systemd-units = stringAfter [ "etc" ] ''
      # Link systemd package units into the system/user directories
      mkdir -p /etc/systemd/system /etc/systemd/user

      for pkg_dir in /etc/systemd/system-packages/*/; do
        [ -d "$pkg_dir" ] || continue
        for unit in "$pkg_dir"/*; do
          [ -f "$unit" ] || continue
          ln -sf "$unit" "/etc/systemd/system/$(basename "$unit")" 2>/dev/null || true
        done
      done

      for pkg_dir in /etc/systemd/user-packages/*/; do
        [ -d "$pkg_dir" ] || continue
        for unit in "$pkg_dir"/*; do
          [ -f "$unit" ] || continue
          ln -sf "$unit" "/etc/systemd/user/$(basename "$unit")" 2>/dev/null || true
        done
      done

      # Link tmpfiles.d from packages
      mkdir -p /etc/tmpfiles.d
      for pkg_dir in /etc/tmpfiles.d/*/; do
        [ -d "$pkg_dir" ] || continue
        for conf in "$pkg_dir"/*; do
          [ -f "$conf" ] || continue
          ln -sf "$conf" "/etc/tmpfiles.d/$(basename "$conf")" 2>/dev/null || true
        done
      done
    '';
  };
}
