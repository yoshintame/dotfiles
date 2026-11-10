default:
    @just --list

check:
    nix flake check --impure

fmt:
    nix fmt

test:
    busted --lpath='modules/home/hammerspoon/config/?.lua' modules/home/hammerspoon/tests

rebuild:
    mise run dot:rebuild

link:
    mise run dot:link

update:
    nix flake update
