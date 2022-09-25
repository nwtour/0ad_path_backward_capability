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

open (my $pipe, "git whatchanged |") or die "Git pipe failed: $!\n";

my %file_list;

sub remove_prefix {
    my $string = shift;
    $string =~ s!^binaries/data/mods/public/!!;
    $string =~ s!\.xml$!!;
    return $string;
}

while (<$pipe>){

	next if !/^:/;
	my @commit_info = split (/\s+/, $_);
	next if $commit_info[4] !~ /^R/; #only rename

	my ($old, $filename) = ($commit_info[5], $commit_info[6]);
	next if $filename !~ /\.xml$/;
	next if $filename !~ /^binaries\/data\/mods\/public\//;

	if (-e $old) {
		print "Old file $old exists in repo. Skip rename.\n";
		next;
	}

	$old = remove_prefix($old);
	# Skip maps and gui files
	next if $old =~ /^(maps|gui)/;

	if (! -e $filename) {

		$filename = remove_prefix($filename);

		if (exists $file_list{ $filename }) {

			print "Double renamed file $filename. Use new destination " . $file_list{ $filename } . "\n";
			$file_list{ $old } = $file_list{ $filename };
		}
		else {
                	print "New file $filename not exists in repo. Object will continue to be inaccessible in the latest release.\n";
		}
		next;
	}

	$filename = remove_prefix($filename);

        $file_list{ $old } = $filename;

	print join ('', "OK ", $old, " => ", $filename, "\n");
}
close ($pipe);

# Sort knowledgebase
@generate_output = sort { $a cmp $b } map { join (":", $_, $file_list{$_}) } (keys %file_list);

write_file (catfile ($Bin, $output_list_file), join ("\n", @generate_output));
