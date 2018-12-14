#!/usr/bin/perl

use strict;
use warnings;
use File::Util;

sub apply_xsl {
 my ($path, $xsl) = @_;

 my $temp = "/tmp/dicom.xml";

 my $w = "dcm2xml -B -I $path > $temp";
 `$w`;
 die "ERROR: Could not execute: $w" if $?;

 my $x = "xsltproc $xsl $temp";
 my $y = `$x`;
 die "ERROR: Could not execute: $x" if $?;
 return $y;
}

sub get_accession_number {
 my ($path) = @_;
 return apply_xsl($path, "xsl/dicom-accession-number.xsl");
}

sub get_series_number {
 my ($path) = @_;
 return apply_xsl($path, "xsl/dicom-series-number.xsl");
}

sub get_instance_number {
 my ($path) = @_;
 return apply_xsl($path, "xsl/dicom-instance-number.xsl");
}

sub read_folder {
 my ($path) = @_;

 opendir(D, $path) || die "ERROR: Could not open folder: $path"; my @list = grep !/^\.\.?$/, readdir(D); closedir D;
 return @list;
}

sub compute_no_collision {
 my ($base_name) = @_;

 my $index = 0;
 my $collision_exists = 1;
 my $proposed_name;
 while ($collision_exists) {
  $index++;
  $proposed_name = "$base_name" . "-" . $index . ".dcm";
  $collision_exists = (-e $proposed_name);
  die "Something went wrong $proposed_name\n" if ($index > 10);
 }
 return $proposed_name;
}

 
sub process_file {
 my ($in_folder, $f, $out_folder) = @_;
 my $old_name = "$in_folder/$f";
 my $instance_number = get_instance_number($old_name);
 my $series_number   = get_series_number($old_name);
 my $accession_number= get_accession_number($old_name);
 my $out_path        = "$out_folder/$accession_number/$series_number";
 my $new_name        = "$out_path/$instance_number" . ".dcm";

 print "Rename: $old_name $new_name\n";
 
 my ($util) = File::Util->new();
 $util->make_dir($out_path) if (! -e $out_path);

 if (-e $new_name) {
   print "WARNING: File already exists with this name: $new_name\nERROR: was working on $old_name\n";
   print "WARNING: Multiple files have the same combination of series number/instance number\n";
   print "WARNING: Computing new file name that does not collide with existing names\n";
   $new_name = compute_no_collision("$out_path/$instance_number");
   print "WARNING: File name without collision is: $new_name\n";
 }
 rename $old_name, $new_name;
}

my $in_folder = $ARGV[0];
my $out_folder = $ARGV[1];
my @files = read_folder($in_folder);
foreach my $f(@files) {
 process_file($in_folder, $f, $out_folder);
}

