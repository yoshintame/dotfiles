#!/usr/bin/env raku

my $dir = prompt "Directory Name: ";
mkdir $dir;
run "lf", "-remote",
"send {%*ENV<id>} select \"{$dir.match(/^<-[/]>+/).subst: '"', '\"', :g}\"";