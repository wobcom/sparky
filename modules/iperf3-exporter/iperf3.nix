{ config, lib, pkgs, options }:

with lib;

let
  cfg = config.services.prometheus-local.exporters.iperf3;
in
{
  port = 9579;
  serviceOpts = {
    serviceConfig = {
      ExecStart = ''
        ${pkgs.prometheus-iperf3-exporter}/bin/iperf3-exporter \
          -web.listen-address ${cfg.listenAddress}:${toString cfg.port} \
          -iperf3.path ${pkgs.iperf3}/bin/iperf3 \
          ${concatStringsSep " \\\n  " cfg.extraFlags}
      '';
    };
  };
}
