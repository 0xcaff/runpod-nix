{ pkgs, ... }:
{
  imports = [
    ./options.nix
    ./host-libs.nix
    ./patched-bin.nix
  ];

  config.runpod = {
    contents = with pkgs; [
      bashInteractive
      coreutils
      cacert
      glibcLocales
      tini
    ];

    env = {
      USER = "root";
      HOME = "/root";
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };

    entrypoint = [ "${pkgs.tini}/bin/tini" "-s" "-g" "--" ];

    extraCommands = [
      ''
        mkdir -p root etc tmp bin usr/sbin
        chmod 1777 tmp
      ''
      ''
        echo "hosts: files dns" > etc/nsswitch.conf
      ''
    ];
  };
}
