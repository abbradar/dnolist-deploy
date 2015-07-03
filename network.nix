let myconfig = import ./config.nix;
    dnocfg = ./config.yaml;
    memory = 512;
    dnolistService = pkgs: service: {
      after = [ "local-fs.target" "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment.DNOLIST_SETTINGS = dnocfg;
      script = "${pkgs.haskellPackages.dnolist}/bin/${service}";
      serviceConfig.Restart = "always";
      serviceConfig.RestartDelay = "500ms";
    };
in
{
  mail = { config, pkgs, ... }:
  {
    deployment.targetEnv = "virtualbox";
    deployment.virtualbox.headless = true;
    deployment.virtualbox.memorySize = memory;
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

    systemd.services.frontend = {
      after = [ "local-fs.target" "network.target" ];
      wantedBy = [ "multi-user.target" ];
      script = "${pkgs.dnolist-frontend}/bin/frontend";
      serviceConfig.Restart = "always";
    };

    networking.firewall.allowedTCPPorts = [ 25 80 143 ];
    networking.firewall.allowPing = true;
  };

  database = { config, pkgs, ... }: {
    deployment.targetEnv = "virtualbox";
    deployment.virtualbox.headless = true;
    deployment.virtualbox.memorySize = memory;
    nixpkgs.config = myconfig;
   
    networking.firewall.allowedTCPPorts = [ 5432 8081 8082 ];

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql94;
      enableTCPIP = true;
      initialScript = ./init-db.sql;
      authentication = pkgs.lib.mkForce ''
        local all all trust
        host  all all 0.0.0.0/0 trust 
      '';
    };

    systemd.services.migration = {
      after = [ "postgresql.target" ];
      wantedBy = [ "multi-user.target" ];
      environment.DNOLIST_SETTINGS = dnocfg;
      script = "${pkgs.haskellPackages.dnolist}/bin/migration";
      serviceConfig.Type = "oneshot";
    };

    systemd.services.session = dnolistService pkgs "session";
    systemd.services.sysop = dnolistService pkgs "sysop";
  };

  smtp-server = { config, pkgs, ... }: {
    deployment.targetEnv = "virtualbox";
    deployment.virtualbox.headless = true;
    deployment.virtualbox.memorySize = memory;
    nixpkgs.config = myconfig;

    networking.firewall.allowedTCPPorts = [ 25 ];

    systemd.services.smtp-server = dnolistService pkgs "smtp-server";
    systemd.services.outgoing-queue = dnolistService pkgs "outgoing-queue";
  };

}
