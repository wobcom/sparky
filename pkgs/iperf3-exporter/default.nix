{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "iperf3-exporter";
  version = "1.3.0";
  src = fetchFromGitHub {
    owner = "wobcom";
    repo = "${pname}";
    rev = "${version}";
    sha256 = "sha256-cNQyl0JnWlOUQii9R3x/gEZUjEr1C3d/Rh1XwJwiwqw=";
  };
  vendorHash = "sha256-V1TQkx05nqLVhmTkIvA9E1K7sLd0SdMUggrfJSZ/A40=";
}
