{ pkgs }:
{
  serverName ? "pulse-server",
  port ? 49152,
  uri ? "mongodb://localhost:27017",
  db ? "pulse"
}:
pkgs.buildGoModule {
  pname = "pulse";
  version = "0.1.5";
  src = ../.;
  vendorHash = "sha256-r7441WMiCMmOCJtGe0tUr4rFlc/nRDd6uiGtNJozNOo=";

  buildInputs = with pkgs; [ go gnumake ];

  subPackages = [ "cmd/server" "cmd/client" ];

  ldflags = [
    "-s" "-w"
    "-X main.serverName=${serverName}"
    "-X main.port=${toString port}"
    "-X main.uri=${uri}"
    "-X main.db=${db}"
  ];

  postInstall = ''
    mv $out/bin/server $out/bin/pulse-server
    mv $out/bin/client $out/bin/pulse-client
  '';
}
