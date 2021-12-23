#!/usr/bin/perl

use strict;

use File::Spec::Functions qw(catfile);

use File::Slurp qw(write_file);
use Getopt::Long qw(GetOptions);
use FindBin qw($Bin);

my $output_list_file = 'list.txt';
my ($gitdir, @generate_output);

GetOptions ("gitdir=s" => \$gitdir);

if (! -d $gitdir) {
	print "Usage: generate_filelist.pl --gitdir=[0ad repo]\n";
	exit;
}

chdir ($gitdir);

open (my $pipe, "git whatchanged -n 20000 |") or die "Git pipe failed: $!\n";

while (<$pipe>){

	next if !/^:/;
	my @commit_info = split (/\s+/,$_);
	next if $commit_info[4] !~ /^R/; #only rename

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
	push @generate_output, join (":", $old, $filename);
	# Sort knowledgebase
	@generate_output = sort { $a cmp $b } @generate_output;
	write_file (catfile ($Bin, $output_list_file), join ("\n", @generate_output));

	print join ('', "OK ", $filename, " => ", $old, "\n");
}
close ($pipe);

