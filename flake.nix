{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    wbba = {
      url = "github:sohalt/write-babashka-application";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    clj-nix = {
      url = "github:jlesquembre/clj-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    self,
    nixpkgs,
    wbba,
    clj-nix,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          wbba.overlays.default
          clj-nix.overlays.default
        ];
      };
      clj2nix = clj-nix.packages.${system};
    in {
      packages = rec {
        default = hello-bb;
        hello-bb = pkgs.writeBabashkaApplication {
          name = "hello-bb";
          text = ''
            (ns hello-bb
              (:require [org.httpkit.server :as server]))
            (server/run-server
              (fn [req] {:status 200
                         :headers {"Content-Type" "text/plain"}
                         :body "Hello Babashka!"})
              {:port 8080})
            @(promise)
          '';
        };
        hello-clj = clj2nix.mkCljBin {
          projectSrc = ./clj;
          name = "hello-clj";
          main-ns = "hello-clj.main";
        };
      };
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          babashka
          clojure
          deps-lock
        ];
      };
    })
    // {
      nixosConfigurations = let
        mkSystem = config:
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [{users.users.root.password = "";} config];
          };
      in rec {
        machine = docker;
        docker = mkSystem {
          virtualisation.oci-containers.containers.hello-world = {
            image = "crccheck/hello-world";
            ports = ["8000:8000"];
          };
          systemd.services."podman-hello-world".after = ["network-online.target"];
          services.openssh.enable = true;
          users.users.root.openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK4o/ncaQUorp/BeZesPnVhzvfoqLJW3WZHtz+CWQvFU leahneukirchen"
            "ssh-ed25520 AAAAC3NzaC1lZDI1NTE5AAAAIMGTXuhbXveoysJ5/MSs2gzOCklodyRJ2wZWwdOAwVtM Sohalt"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMIv1UwEJntvBa/gTYIbQPMkOujoergt1DNa8bulAmgm Sohalt"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINDrsavxeQzfkxRNvGwnnrJHQihHFDqQmXwryWcQ0pOH Sohalt"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL77PSaQffTINo5ezcZPzcg1/YZq4o30hw8KuMz/pWHm Sohalt"
          ];
        };
        hello-clj = mkSystem {
          systemd.services.hello-clj = {
            enable = true;
            serviceConfig = {
              ExecStart = "${self.packages.x86_64-linux.hello-clj}/bin/hello-clj";
            };
          };
        };
        hello-bb = mkSystem {
          systemd.services.hello-bb = {
            enable = true;
            serviceConfig = {
              ExecStart = "${self.packages.x86_64-linux.hello-bb}/bin/hello-bb";
            };
          };
        };
      };
    };
}
