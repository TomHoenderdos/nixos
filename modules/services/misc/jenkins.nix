{ config, pkgs, ... }:

with pkgs.lib;

let
  cfg = config.services.jenkins;
in

{
  ###### interface
  options = {  
    services.jenkins.enable = mkOption {
        default = false;       
        description = ''Wether to enable Jenkins or not.'';
    };

    services.jenkins.user = mkOption {
        default = "jenkins";
        description = "User account under which Jenkins runs.";
    };


  }; 

  ###### implementation
  config = mkIf cfg.enable {
    
    users.extraGroups = optionalAttrs (cfg.user == "jenkins") (singleton
    {
        name = "jenkins";
    });

    users.extraUsers = optionalAttrs (cfg.user == "jenkins") (singleton
      { name = "jenkins";
        group = "jenkins";
        isSystemUser = true;
        description = "Jenkins user";
        home = "/var/lib/jenkins";
        createHome = true;
      });

    systemd.services.jenkins = {
      
      description = "Jenkins CI";
      wantedBy = [ "multi-user.target" ];
      serviceConfig =
      { ExecStart = "${pkgs.jenkins}/bin/jenkins";
        User = cfg.user;
        Group = cfg.user;
        StandardInput = "";
        StandardOutput = "";
        Restart = "always";
      };
    };
  };
}
