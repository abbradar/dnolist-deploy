let myconfig = import ./config.nix;
    dnocfg = ./config.yaml;
    dnolistMachine = service: { config, pkgs, ... }: {
      deployment.targetEnv = "virtualbox";
      deployment.virtualbox.headless = true;
      nixpkgs.config = myconfig;

      networking.firewall.allowedTCPPorts = [ 25 80 ];

      systemd.services.${service} = {
        after = [ "local-fs.target" "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment.DNOLIST_SETTINGS = dnocfg;
        script = "${pkgs.haskellPackages.dnolist}/bin/${service}";
        serviceConfig.Restart = "always";
      };

    };
in
{
  mail = { config, pkgs, ... }:
  {
    deployment.targetEnv = "virtualbox";
    deployment.virtualbox.headless = true;
    nixpkgs.config = myconfig;

    environment.systemPackages = with pkgs; [
      opensmtpd
    ];

    services.opensmtpd = {
      enable = true;
      serverConfiguration = ''
        listen on 0.0.0.0
        accept from any for local deliver to lmtp "/var/run/dovecot2/lmtp"
        accept from any for domain list deliver to lmtp smtp-incoming:25
      '';
    };

    services.dovecot2 = {
      enable = true;
      enableLmtp = true;
      extraConfig = ''
        userdb {
          driver = static
          args = uid=${toString config.ids.uids.dovecot2} gid=${toString config.ids.gids.dovecot2}
        }
        passdb {
          driver = static
          args = proxy=y nopassword=y
        }
      '';
    };

    networking.firewall.allowedTCPPorts = [ 25 143 ];
    networking.firewall.allowPing = true;
  };

  frontend = { config, pkgs, ... }: {
    deployment.targetEnv = "virtualbox";
    deployment.virtualbox.headless = true;
    nixpkgs.config = myconfig;

    networking.firewall.allowedTCPPorts = [ 80 ];
    networking.firewall.allowPing = true;

    systemd.services.frontend = {
      after = [ "local-fs.target" "network.target" ];
      wantedBy = [ "multi-user.target" ];
      script = "${pkgs.dnolist-frontend}/bin/frontend";
      serviceConfig.Restart = "always";
    };
  };

  database = { config, pkgs, ... }: {
    deployment.targetEnv = "virtualbox";
    deployment.virtualbox.headless = true;
    nixpkgs.config = myconfig;
   
    networking.firewall.allowedTCPPorts = [ 5432 ];

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql94;
      enableTCPIP = true;
    };

    systemd.services.migration = {
      after = [ "postgresql.target" ];
      wantedBy = [ "multi-user.target" ];
      environment.DNOLIST_SETTINGS = dnocfg;
      script = "${pkgs.haskellPackages.dnolist}/bin/migration";
      serviceConfig.Type = "oneshot";
    };
  };

  session = dnolistMachine "session";
  sysop = dnolistMachine "sysop";
  outgoing-queue = dnolistMachine "outgoing-queue";
  smtp-server = dnolistMachine "smtp-server";

}
