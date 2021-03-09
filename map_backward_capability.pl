#!/usr/bin/perl

use strict;

use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use File::Path qw(make_path);
use File::Copy qw(copy);
use File::Temp qw(tmpnam);

use JSON qw(to_json);
use English qw($EFFECTIVE_USER_ID $PROGRAM_NAME);
use File::Slurp qw(write_file);
use Data::Dumper;
use Getopt::Long qw(GetOptions);
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use FindBin qw($Bin);

print "$PROGRAM_NAME\n";

my ($gitdir,$commit, $date, @recheck);

my $file_extentions = qr/(\.xml|\.png|\.dae|\.dds)$/;

# Make mod for developer version of 0ad
# git clone https://github.com/0ad/0ad.git
# cd 0ad
# perl path_backward_capability.pl
# For version 24, change $version and run git checkout 3815c082925df90726f0207edd53497407ebff99
my $version = 25;

GetOptions("version=i" => \$version, "gitdir=s" => \$gitdir);

my $current_tmp_file = tmpnam();

if(! -d $gitdir) {
	print "Usage: perl map_backward_capability.pl --version=[24|25] --gitdir=[0ad repo]\n";
	exit;
}

chdir($gitdir);

my $zip = Archive::Zip->new();

write_file($current_tmp_file, qq/
{
    "name": "path_backward_capability$version",
    "version": "1.$version.1",
    "label": "path_backward_capability$version",
    "description": "Backward capability renamed filenames in 0 A.D.",
    "dependencies": ["0ad=0.0.$version"]
}
/);

$zip->addFile($current_tmp_file, 'mod.json');

# Generate knowledge databases renamed files
my $json_list_file = 'map_backward_capability_list.json';
my $generate_json = [];

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

	my $name_in_mod_tree = $short;

	push @{$generate_json}, [$old, $filename, "https://github.com/0ad/0ad/commit/$commit", $date];
	# Sort knowledgebase
	@{$generate_json} = sort { $a->[0] cmp $b->[0] } @{$generate_json};
	write_file(catfile($Bin, $version, $json_list_file), to_json($generate_json, {utf8 => 1, pretty => 1}));

	print join('', "OK ", $filename, " => ", $name_in_mod_tree, "\n");
	$zip->addDirectory(dirname($name_in_mod_tree));
	my $zip_member = $zip->addFile($filename, $name_in_mod_tree);
	$zip_member->desiredCompressionLevel(9);
}
close($pipe);

$zip->addFile(catfile($Bin, $version, $json_list_file), $json_list_file);

$zip->addDirectory('maps/skirmishes');

$zip->writeToFileNamed(catfile($Bin, $version, 'map_backward_capability25.zip'));

unlink $current_tmp_file;

#TODO @recheck
