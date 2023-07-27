{ python311
, fetchFromGitHub
}:

let
  py = python311.override {
    packageOverrides = python3-final: python3-prev: {
      django-bootstrap5 = python3-final.callPackage ./python-modules/django-bootstrap5.nix { };
      fontawesomefree = python3-final.callPackage ./python-modules/fontawesomefree.nix { };
      macaddress = python3-final.callPackage ./python-modules/macaddress.nix { };
      reprshed = python3-final.callPackage ./python-modules/reprshed.nix { };
    };
  };

in py.pkgs.buildPythonApplication rec {
  pname = "sparky-web";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "wobcom";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-QOENkZHxxrSa/FeVnRCGySf8sWPcB0jx9jDB1f3+4l8=";
  };

  format = "other";

  propagatedBuildInputs = with py.pkgs; [
    django
    django-bootstrap5
    fontawesomefree
    macaddress
    psycopg2
    requests
    pytz
    gitpython
  ];

  buildPhase = ''
    runHook preBuild
    cp sparky_web/configuration{.example,}.py
    python3 manage.py collectstatic --no-input
    rm -f sparky_web/configuration.py
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/opt/sparky-web
    cp -r . $out/opt/sparky-web
    chmod +x $out/opt/sparky-web/manage.py
    makeWrapper $out/opt/sparky-web/manage.py $out/bin/sparky-web \
      --prefix PYTHONPATH : "$PYTHONPATH"
    runHook postInstall
  '';

  passthru = {
    # PYTHONPATH of all dependencies used by the package
    python = py;
    pythonPath = py.pkgs.makePythonPath propagatedBuildInputs;
  };
}