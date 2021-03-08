#!/usr/bin/perl

use strict;

use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use File::Path qw(make_path);
use File::Copy qw(copy);

use JSON qw(to_json from_json);
use English qw($EFFECTIVE_USER_ID);
use File::Slurp qw(read_file write_file);
use Data::Dumper;

my ($commit, @recheck, %generate_json);

my $file_extentions = qr/(\.xml|\.json|\.png|\.dae|\.dds)$/;

# Make mod for developer version of 0ad
# git clone https://github.com/0ad/0ad.git
# cd 0ad
# perl path_backward_capability.pl
# For version 24, change $version and run git checkout 3815c082925df90726f0207edd53497407ebff99
my $version = 25;

# Tested in UNIX environment
my $mod_root = "/home/" . getpwuid($EFFECTIVE_USER_ID) . "/.local/share/0ad/mods/path_backward_capability$version";


write_file(catfile($mod_root, 'mod.json'), qq/
{
    "name": "path_backward_capability$version",
    "version": "1.$version.1",
    "label": "path_backward_capability$version",
    "description": "Backward capability renamed filenames in 0 A.D.",
    "dependencies": ["0ad=0.0.$version"]
}
/);

# Generate knowledge databases renamed files
my $json_list_file = 'path_backward_capability_list.json';

eval { %generate_json = from_json(read_file(catfile($mod_root, $json_list_file))); };

open(my $pipe, "git whatchanged |") or die "Git pipe failed: $!\n";

while(<$pipe>){

	$commit = $1 if /^commit\s([a-f0-9]{40})/;
	next if !/^:/;
	my @commit_info = split(/\s+/,$_);
	next if $commit_info[4] !~ /^R/;

	my ($old, $filename) = ($commit_info[5], $commit_info[6]);
	next if $filename !~ /$file_extentions/;
	next if $filename !~ /^binaries\/data\/mods\/public/;

	if(-e $old) {
		print "Err old file $old exists\n";
		next;
	}
	elsif(! -e $filename){
		push @recheck, $filename;
	}

	my $name_in_mod_tree = catfile($mod_root, $old);

	$name_in_mod_tree =~ s/binaries\/data\/mods\/public\///;

	next if -e $name_in_mod_tree;

	$generate_json{$old} = [$filename, "https://github.com/0ad/0ad/commit/$commit"];
	write_file(catfile($mod_root, $json_list_file), to_json(\%generate_json, {utf8 => 1, pretty => 1}));

	print join('', "OK ", $filename, " => ", $name_in_mod_tree, "\n");
	make_path(dirname($name_in_mod_tree), {verbose => 1});
	copy($filename, $name_in_mod_tree);
}
close($pipe);

