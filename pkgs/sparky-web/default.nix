{ python3
, fetchFromGitHub

, plugins ? ps: []
}:

python3.pkgs.buildPythonApplication rec {
  pname = "sparky-web";
  version = "1.7.1";

  src = fetchFromGitHub {
    owner = "wobcom";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-3+IH3nYpDn+B1mO6JFHdv0EN7eDHn2JmbvvyQDzNq0s=";
  };

  format = "other";

  propagatedBuildInputs = with python3.pkgs; [
    django
    django-bootstrap5
    fontawesomefree
    macaddress
    psycopg2
    requests
    pytz
    gitpython
  ] ++ plugins python3.pkgs;

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
    python = python3;
    pythonPath = python3.pkgs.makePythonPath propagatedBuildInputs;
  };
}
