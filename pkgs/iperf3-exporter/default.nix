{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "iperf3-exporter";
  version = "1.2.1";

  src = fetchFromGitHub {
    owner = "wobcom";
    repo = "${pname}";
    rev = "${version}";
    sha256 = "sha256-Ovdi7BybBBMkXv4ced7F8M+4rKPsXjLFTtmGxUpibeE=";
  };

  vendorHash = "sha256-V1TQkx05nqLVhmTkIvA9E1K7sLd0SdMUggrfJSZ/A40=";
}
