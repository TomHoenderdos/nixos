{ config, pkgs, ... }:

with pkgs.lib;

let

  cfg = config.services.storm;

  storm = pkgs.storm.override { logsDir = cfg.logDir; confDir = dirOf stormCnf; };
  jzmq  = pkgs.jzmq;

  stormCnf = pkgs.writeText "storm.conf"
  ''
    java.library.path: "${jzmq}/lib:${jzmq}/share/java:${concatStringsSep ":" cfg.extraLibraryPaths}"
    storm.local.dir: "${cfg.serverDir}"

    storm.zookeeper.servers:
    ${concatMapStrings (host: "    - \"${host}\"") cfg.zookeeperHosts}

    nimbus.host: "${cfg.nimbusHost}"
    ${cfg.yaml}
  '';

  mkService = name:
    { description = "Storm ${name} daemon";

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      preStart =
        ''
          mkdir -p "${cfg.serverDir}" "${cfg.logDir}";
          install -m0705 -o ${cfg.user} -g "nogroup" -d "${cfg.serverDir}";
          install -m0705 -o ${cfg.user} -g "nogroup" -d "${cfg.logDir}";

          cd "${cfg.serverDir}";
          if ! test -L .storm; then ln -fs "${dirOf stormCnf}" .storm; fi;
        '';

      path = [ pkgs.jdk storm ];

      serviceConfig = {
        WorkingDirectory = cfg.serverDir;
        ExecStart = "${storm}/bin/storm ${name} --config ${baseNameOf stormCnf}";
        User = cfg.user;
        PermissionsStartOnly = true;
        Restart = "always";
      };
    };

in
{

  ###### interface

  options = {

    services.storm = {
      # Enabling Storm
      supervisor = mkOption {
        description = "Whether to enable the Storm Supervisor daemon.";
        default = false;
        type = types.bool;
      };
      nimbus = mkOption {
        description = "Whether to enable the Storm Nimbus (master node) daemon.";
        default = false;
        type = types.bool;
      };
      drpc = mkOption {
        description = "Whether to enable the Storm Distributed-RPC daemon.";
        default = false;
        type = types.bool;
      };
      ui = mkOption {
        description = "Whether to enable the Storm UI daemon.";
        default = false;
        type = types.bool;
      };

      # Configuration
      nimbusHost = mkOption {
        description = "Nimbus host.";
        type = types.string;
      };

      zookeeperHosts = mkOption {
        description = "Zookeeper hosts.";
        type = types.listOf types.string;
      };

      yaml = mkOption {
        description = "Additional storm.yaml configuration entries.";
        default = "";
        type = types.string;
      };

      extraLibraryPaths = mkOption {
        description = "Additional paths to library directories and jars Storm should know about.";
        default = [];
        type = types.listOf types.path;
      };

      serverDir = mkOption {
        description = "Location of the Storm processes instance files.";
        default = "/var/lib/storm";
        type = types.path;
      };

      logDir = mkOption {
        description = "Where to keep Storm log files.";
        default = "/var/log/storm";
        type = types.path;
      };

      user = mkOption {
        description = "User account under which Storm daemons run.";
        default = "storm";
        type = types.string;
      };

    };

  };


  ###### implementation

  config = mkMerge [
    (mkIf (cfg.supervisor || cfg.nimbus || cfg.drpc || cfg.ui) {

      users.extraUsers = singleton
        { name = cfg.user;
          home = cfg.serverDir;
          description = "Storm daemons";
          group = "nogroup";
          isSystemUser = true;
          createHome = true;
        };

      environment.systemPackages = [ storm ];
    })

    (mkIf cfg.supervisor { systemd.services.storm-supervisor = mkService "supervisor"; })
    (mkIf cfg.nimbus     { systemd.services.storm-nimbus     = mkService "nimbus"    ; services.storm.nimbusHost = "127.0.0.1"; })
    (mkIf cfg.drpc       { systemd.services.storm-drpc       = mkService "drpc"      ; })
    (mkIf cfg.ui         { systemd.services.storm-ui         = mkService "ui"        ; })
  ];
}
