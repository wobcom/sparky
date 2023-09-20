{ ... }:

{
  config = {
    profiles.sparky-tailnet.headscaleURL = "https://sparky-headscale.example.com"; # URL of the Headscale
    profiles.sparky-probe.headscaleIP = "fd8f:89ae:ca73:1::1"; # IP of the Headscale VM in the Tailnet (used as SSH JumpHost)
    profiles.sparky-probe.metricsIP = "fd8f:89ae:ca73:2::1"; # IP of the VictoriaMetrics VM in the Tailnet
    profiles.sparky-probe.webURL = "https://sparky.example.com"; # URL of the SPARKY-Webinterface (used for API requests)
  };
}