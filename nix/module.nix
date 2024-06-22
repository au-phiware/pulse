{ config, pkgs, lib, ... }:
let
  cfg = config.services.pulse;
in {
  options.services.pulse = {
    enable = lib.mkEnableOption "Pulse service";

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "creativecreature-pulse-server";
      description = "Server name for Pulse";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 49152;
      description = "Port number for Pulse server";
    };

    uri = lib.mkOption {
      type = lib.types.str;
      default = "mongodb://localhost:27017";
      description = "MongoDB URI for Pulse";
    };

    db = lib.mkOption {
      type = lib.types.str;
      default = "creativecreature-pulse";
      description = "Database name for Pulse";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.creativecreature-pulse = let
      pulse = import ./builder.nix {
        inherit pkgs;
      } {
        inherit (cfg) serverName port uri db;
      };
    in {
      description = "Pulse Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "mongodb.service" ];
      requires = [ "mongodb.service" ];
      serviceConfig = {
        ExecStart = "${pulse}/bin/pulse-server";
        Restart = "always";
        StandardError = "journal";
        StandardOutput = "journal";
        StateDirectory = "pulse";
        WorkingDirectory = "/var/lib/pulse";
        Environment = "HOME=/var/lib/pulse";
      };
    };

    services.mongodb = lib.mkIf (cfg.uri == "mongodb://localhost:27017") {
      enable = true;
    };
  };
}
