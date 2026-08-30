default:
    @just --list

check:
    nix flake check --impure

fmt:
    nix fmt

rebuild:
    mise run dot:rebuild

link:
    mise run dot:link

update:
    nix flake update
