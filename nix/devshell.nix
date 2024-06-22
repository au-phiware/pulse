{ pkgs, mprocs }:

let
  mprocsPackage = pkgs.rustPlatform.buildRustPackage {
    pname = "mprocs";
    version = "0.7.0-rc1-${builtins.substring 0 8 mprocs.rev}";

    src = mprocs;

    cargoLock = {
      lockFile = "${mprocs}/Cargo.lock";
    };

    meta = with pkgs.lib; {
      description = "A TUI tool to run multiple commands in parallel and show the output of each command separately";
      homepage = "https://github.com/pvolok/mprocs";
      license = licenses.mit;
      maintainers = with maintainers; [ GaetanLepage pyrox0 ];
      mainProgram = "mprocs";
    };
  };

  # Function to find an available port
  findAvailablePort = start: end: ''
    for port in $(${pkgs.coreutils}/bin/seq ${toString start} ${toString end}); do
      if ! ${pkgs.iproute2}/bin/ss -tuln | ${pkgs.gnugrep}/bin/grep -q ":$port "; then
        echo $port
        break
      fi
    done
  '';

  # Pulse Vim plugin that is linked to the 'live' pulse-client binary
  pulseVimPlugin = pkgs.vimUtils.buildVimPlugin {
    name = "pulse-vim-plugin";
    src = pkgs.lib.cleanSourceWith {
      src = ./..;
      filter = path: type: (pkgs.lib.hasPrefix (toString ./.. + "/plugin") path);
    };
    dontBuild = true;
    postInstall = ''
      substituteInPlace $out/plugin/pulse.vim \
        --replace-fail "['pulse-client']" "['${pulseClientWrapper}/bin/pulse-client']" \
        --replace-quiet "system('uuidgen')" "system('${pkgs.util-linux}/bin/uuidgen')"
    '';
  };

  # Development environment specific scripts
  pulseClientWrapper = pkgs.writeShellScriptBin "pulse-client" ''
    export HOME=$PULSE_PROJECT_ROOT/tmp/home
    exec "$PULSE_PROJECT_ROOT/bin/pulse-client" "$@"
  '';

  pulseServerWrapper = pkgs.writeShellScriptBin "pulse-server" ''
    export HOME=$PULSE_PROJECT_ROOT/tmp/home
    exec "$PULSE_PROJECT_ROOT/bin/pulse-server" "$@"
  '';

  startBuilder = pkgs.writeShellScriptBin "start-builder" ''
    exec ${pkgs.watchexec}/bin/watchexec \
      --on-busy-update=queue \
      --filter '*.go' --filter Makefile --filter go.mod --filter go.sum \
      --shell=none \
      -- ${pkgs.gnumake}/bin/make audit bin/pulse-server bin/pulse-client
  '';

  # Wrapper for pulse-server to kill the parent process if the server
  # exits with a non-zero status. This is a workaround for the fact that
  # watchexec doesn't support restarting a process when its child process
  # crashes. See https://github.com/watchexec/watchexec/issues/132
  pulseServerWorker = pkgs.writeShellScriptBin "pulse-server" ''
    ${pulseServerWrapper}/bin/pulse-server "$@"
    if [ $? -ne 0 ]; then
      kill $PPID
    fi
  '';
  startService = pkgs.writeShellScriptBin "start-pulse-service" ''
    ${pkgs.watchexec}/bin/watchexec \
      --restart \
      --watch $PULSE_PROJECT_ROOT/bin \
      --filter pulse-server \
      -- ${pulseServerWorker}/bin/pulse-server "$@"
  '';

  startDatabase = pkgs.writeShellScriptBin "start-database" ''
    exec ${pkgs.mongodb}/bin/mongod \
      --dbpath $PULSE_PROJECT_ROOT/tmp/db \
      --port $MONGO_PORT | ${pkgs.jaq}/bin/jaq
  '';

  start = pkgs.writeShellScriptBin "start" ''
    exec ${mprocsPackage}/bin/mprocs
  '';

  neovimWithPulse = pkgs.neovim.override {
    configure = {
      packages.pulse = with pkgs.vimPlugins; {
        start = [ pulseVimPlugin ];
      };
    };
  };

in
pkgs.mkShell {
  buildInputs = with pkgs; [
    go go-tools
    gnumake
    mongodb
    neovimWithPulse
    mprocsPackage
    util-linux # For uuidgen
    watchexec
    start
    startBuilder
    startService
    startDatabase
    pulseClientWrapper
    pulseServerWrapper
  ];

  shellHook = ''
    # Set the project root to the current directory when the shell is first entered
    export PULSE_PROJECT_ROOT=$(pwd)
    ${pkgs.coreutils}/bin/mkdir -p $PULSE_PROJECT_ROOT/tmp/{db,home}

    # Use environment variables if set, otherwise find available ports
    export PULSE_PORT=''${PULSE_PORT:-$(${findAvailablePort "49152" "65535"})}
    export MONGO_PORT=''${MONGO_PORT:-$(${findAvailablePort "27017" "28000"})}

    export SERVER_NAME=pulse-dev-server
    export PORT=$PULSE_PORT
    export DB=pulse-dev
    export URI=mongodb://localhost:$MONGO_PORT

    echo "Development environment ready!"
    echo "Pulse server will run on port $PULSE_PORT"
    echo "MongoDB will run on port $MONGO_PORT"
    echo "To override ports, set PULSE_PORT and/or MONGO_PORT environment variables"
    echo "To start devshell, run: start"
    echo
    echo "Note: This development environment uses MongoDB, which is under the SSPL license."
  '';
}
