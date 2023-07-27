final: prev: {
  prometheus-iperf3-exporter = final.callPackage ./iperf3-exporter { };
  sparky-web = final.callPackage ./sparky-web { };
}