{ python311
, fetchFromGitHub

, plugins ? ps: []
}:

python311.pkgs.buildPythonApplication rec {
  pname = "sparky-web";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "wobcom";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-ZdUdHBHFdWiFpqhgZbE5OAQoMtyFrRFFU0ZLKbLJFtQ=";
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
  ] ++ plugins python311.pkgs;

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