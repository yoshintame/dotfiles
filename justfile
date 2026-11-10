default:
    @just --list

check:
    nix flake check --impure

fmt:
    nix fmt

test:
    cd modules/home/hammerspoon/config/Spoons/SmsOtp.spoon && busted

rebuild:
    mise run dot:rebuild

link:
    mise run dot:link

update:
    nix flake update
