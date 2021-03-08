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

my ($commit, $date, @recheck);

my $file_extentions = qr/(\.xml|\.json|\.png|\.dae|\.dds)$/;

# Make mod for developer version of 0ad
# git clone https://github.com/0ad/0ad.git
# cd 0ad
# perl path_backward_capability.pl
# For version 24, change $version and run git checkout 3815c082925df90726f0207edd53497407ebff99
my $version = 25;

# Tested in UNIX environment
my $mod_root = "/home/" . getpwuid($EFFECTIVE_USER_ID) . "/.local/share/0ad/mods/path_backward_capability$version";

make_path($mod_root) if ! -d $mod_root;

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
my $generate_json = [];
eval { $generate_json = from_json(read_file(catfile($mod_root, $json_list_file))); };

# Github limit ~50Mb
my $num_of_commit = 3500;

open(my $pipe, "git whatchanged -n $num_of_commit |") or die "Git pipe failed: $!\n";

while(<$pipe>){

	$commit = $1 if /^commit\s([a-f0-9]{40})/;
	$date   = $1 if /^Date:\s+(.+)/;
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
		next;
	}

	my $short = $old;
	$short =~ s/binaries\/data\/mods\/public\///;

	# Skip maps and gui files
	next if $short =~ /^(maps|gui)/;

	my $name_in_mod_tree = catfile($mod_root, $short);

	# Restarting will complete work
	next if -e $name_in_mod_tree;

	push @{$generate_json}, [$old, $filename, "https://github.com/0ad/0ad/commit/$commit", $date];
	# Sort knowledgebase
	@{$generate_json} = sort { $a->[0] cmp $b->[0] } @{$generate_json};
	write_file(catfile($mod_root, $json_list_file), to_json($generate_json, {utf8 => 1, pretty => 1}));

	print join('', "OK ", $filename, " => ", $name_in_mod_tree, "\n");
	make_path(dirname($name_in_mod_tree), {verbose => 1});
	copy($filename, $name_in_mod_tree);
}
close($pipe);

make_path(catfile($mod_root, 'maps', 'skirmishes'));

#TODO @recheck
