{ lib, pkgs, config, ... }:
let
  cfg = config.services.ndpresponder;

  capabilityBoundingSet = [ "CAP_NET_RAW" "CAP_NET_ADMIN" ];
in
{
  options.services.ndpresponder = {
    enable = lib.mkEnableOption (lib.mdDoc "ndpresponder");
    package = lib.mkPackageOptionMD pkgs "ndpresponder" { };

    interface = lib.mkOption {
      type = lib.types.str;
      example = "eth0";
      description = lib.mdDoc ''
        Uplink network interface.
      '';
    };

    subnets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "2001:db8::/32" ];
      description = lib.mdDoc ''
        Static target IPv6 subnets.
      '';
    };

    dockerNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = lib.mdDoc ''
        Docker network names.
      '';
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = lib.mdDoc ''
        Extra flags passed to the ndpresponder command in the service definition.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.ndpresponder = {
      description = "NDP Responder";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "exec";
        Restart = "always";

        ExecStart =
          let
            args = [ (lib.getExe cfg.package) "--ifname" cfg.interface ]
              ++ lib.concatMap (x: [ "--subnet" x ]) cfg.subnets
              ++ lib.concatMap (x: [ "--docker-network" x ]) cfg.dockerNetworks
              ++ cfg.extraFlags;
          in
          lib.escapeShellArgs args;

        DynamicUser = true;
        CapabilityBoundingSet = capabilityBoundingSet;
        AmbientCapabilities = capabilityBoundingSet;

        UMask = "0077";
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectHome = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        PrivateDevices = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" "~@resources" "~@privileged" ];
        SystemCallErrorNumber = "EPERM";
      };
    };
  };

  meta.maintainers = [ lib.maintainers.tie ];
}
