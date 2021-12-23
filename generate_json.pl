#!/usr/bin/perl

use strict;

use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tmpnam);

use JSON qw(to_json);
use File::Slurp qw(write_file);
use Getopt::Long qw(GetOptions);
use FindBin qw($Bin);

my $gitdir;

GetOptions ("gitdir=s" => \$gitdir);

if (! -d $gitdir) {
	print "Usage: generate_json.pl --gitdir=[0ad repo]\n";
	exit;
}

chdir ($gitdir);

my $json_list_file = 'list.json';
my $generate_json = [];

open (my $pipe, "git whatchanged -n 10000 |") or die "Git pipe failed: $!\n";

while (<$pipe>){

	#$commit = $1 if /^commit\s([a-f0-9]{40})/;
	#$date   = $1 if /^Date:\s+(.+)/;
	next if !/^:/;
	my @commit_info = split (/\s+/,$_);
	next if $commit_info[4] !~ /^R/;

	my ($old, $filename) = ($commit_info[5], $commit_info[6]);
	next if $filename !~ /\.xml$/;
	next if $filename !~ /^binaries\/data\/mods\/public\//;

	if (-e $old) {
		print "Err old file $old exists\n";
		next;
	}
	elsif (! -e $filename){
		next;
	}

	my $short = $old;
	$short =~ s!binaries/data/mods/public/!!;

	# Skip maps and gui files
	next if $short =~ /^(maps|gui)/;

	my $name_in_mod_tree = $short;

	$filename =~ s!^binaries/data/mods/public/!!;	$filename =~ s!\.xml$!!;
	$old =~ s!^binaries/data/mods/public/!!;	$old =~ s!\.xml$!!;
	push @{$generate_json}, [$old, $filename];
	# Sort knowledgebase
	@{$generate_json} = sort { $a->[0] cmp $b->[0] } @{$generate_json};
	write_file (catfile ($Bin, $json_list_file), to_json ($generate_json, {utf8 => 1, pretty => 1}));

	print join('', "OK ", $filename, " => ", $old, "\n");
}
close ($pipe);

