{ lib
, buildPythonPackage
, fetchFromGitHub

# build-system
, hatchling

# dependencies
, beautifulsoup4
, pillow
, django
}:

buildPythonPackage rec {
  pname = "django-bootstrap5";
  version = "23.3";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "zostera";
    repo = "django-bootstrap5";
    rev = "v${version}";
    hash = "sha256-FIwDyZ5I/FSaEiQKRfanzAGij86u8y85Wal0B4TrI7c=";
  };

  nativeBuildInputs = [
    hatchling
  ];

  preBuild = ''
    substituteInPlace pyproject.toml \
      --replace "\"Framework :: Django :: 4.2\"," ""
  '';

  propagatedBuildInputs = [
    django
    beautifulsoup4
    pillow
  ];

  pythonImportsCheck = [
    "django_bootstrap5"
  ];

  meta = with lib; {
    description = "Bootstrap 5 integration with Django";
    homepage = "https://github.com/zostera/django-bootstrap5";
    changelog = "https://github.com/zostera/django-bootstrap5/blob/${src.rev}/CHANGELOG.md";
    license = licenses.bsd3;
    maintainers = with maintainers; [ netali ];
  };
}