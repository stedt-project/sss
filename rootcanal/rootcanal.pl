#! /usr/bin/perl
# use lib '../lib';
# This file should be placed in some executable directory on your web server.
# A sample BEGIN block has been put here; put in the relevant directories
# or remove if you don't need it.
# Obviously you need to put in the path to your config file.
BEGIN { 
        $^W = 1; 
        unshift @INC, "../pm", "../lib"  if -e "../pm";
}
use STEDT::RootCanal::Dispatch;

STEDT::RootCanal::Dispatch->dispatch(
	args_to_new => {
		PARAMS => {
			cfg_file => '/home/stedt-cgi/rootcanal.conf'
		}
	}
);
