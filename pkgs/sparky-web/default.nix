{ python311
, fetchFromGitHub
}:

python311.pkgs.buildPythonApplication rec {
  pname = "sparky-web";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "wobcom";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-n8egAHBLu75uP69s1Ktw7rKF0QYLXbIbMQ5f5bQqhnU=";
  };

  format = "other";

  propagatedBuildInputs = with python311.pkgs; [
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
    python = python311;
    pythonPath = python311.pkgs.makePythonPath propagatedBuildInputs;
  };
}