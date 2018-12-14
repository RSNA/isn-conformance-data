#!/usr/bin/perl

# Script creates list of series UIDs for images in a collection
# Arguments:	Collection name

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Headers;
use Getopt::Long;
use File::Util;

sub print_help {
  print "Usage: [-c collection] [-p patient_id] [-u study_uid] output_folder\n";
  exit(1);
}

sub initialize_http {
 my $HTTP = HTTP::Headers->new;
 $HTTP::Headers::TRANSLATE_UNDERSCORE = undef;
}

sub execute_get {
 my ($url, $api_key) = @_;
 my $field_name = "api\_key";

 my %h = ($field_name => $api_key);
 my $ua = LWP::UserAgent->new;

 my $req = HTTP::Request->new(GET => $url);
 $req->header(%h);

 my $resp = $ua->request($req);
 if ($resp->is_success) {
  my $message = $resp->decoded_content;
  my @lines = split /\n/, $message;
  return @lines;
 } else {
  print "Error code:    ", $resp->status_line, "\n";
  print "Error code:    ", $resp->code, "\n";
  print "Error message: ", $resp->message,  "\n";
  die "Could not execute: $url\n";
 }
}

sub execute_get_image {
 my ($url, $api_key) = @_;
 my $field_name = "api\_key";

 my %h = ($field_name => $api_key);
 my $ua = LWP::UserAgent->new;

 my $req = HTTP::Request->new(GET => $url);
 $req->header(%h);

 my $resp = $ua->request($req);
 if ($resp->is_success) {
  my $message = $resp->decoded_content;
  return $message;
 } else {
  print "Error code:    ", $resp->status_line, "\n";
  print "Error code:    ", $resp->code, "\n";
  print "Error message: ", $resp->message,  "\n";
  die "Could not execute: $url\n";
 }
}

sub get_series_values {
 my ($base, $key, $collection, $study_uid)  = @_;
 my $delimiter = "";
 my $url = $base . "/query/getSeries?";
 if ($collection) {
  $url .= $delimiter . "Collection=$collection";
  $delimiter = "&";
 }
 if ($study_uid) {
  $url .= $delimiter . "StudyInstanceUID=$study_uid";
  $delimiter = "&";
 }
 $url .= $delimiter . "&format=csv";

 my @values = execute_get($url, $key);
 my $header = shift @values;
# die "Expected 'Series' as first row in response; received '$header'" if ($header ne "Series");
 return @values;
}

sub get_patient_study_values {
 my ($base, $key, $collection, $patient_id, $uid)  = @_;
 my $url = $base . "/query/getPatientStudy?";
 my $delimiter = "";
 print "$url\n";
 if ($collection) {
  $url .= $delimiter . "Collection=$collection";
  $delimiter = "&";
 }
 print "$url\n";
 if ($patient_id) {
  $url .= "PatientID=$patient_id";
  $delimiter = "&";
 };
 print "$url\n";
 if ($uid) {
  $url .= "StudyInstanceUID=$uid";
  $delimiter = "&";
 };
 print "$url\n";
 $url .= $delimiter . "format=csv";

 my @values = execute_get($url, $key);
 my $header = shift @values;
 return @values;
}

sub get_patient_values {
 my ($base, $key, $collection)  = @_;
 my $url = $base . "/query/getPatient?Collection=$collection" . "&format=csv";
 my @values = execute_get($url, $key);
 my $header = shift @values;
 die "Expected 'PatientID,PatientName,PatientSex,Collection' as first row in response; received '$header'" if ($header ne "PatientID,PatientName,PatientSex,Collection");
 return @values;
}

sub print_collection_resources {
 my $collection = shift @_;
 my $resource   = shift @_;

 foreach my $v(@_) {
  my $m = substr $v, 1, -1;
  print "$collection, $resource, $m \n";
 }
}

sub process_series {
 my $output_folder = shift @_;
 my $base = shift @_;
 my $key  = shift @_;
 my $patient  = shift @_;
 my $study    = shift @_;

 my $path = "$output_folder/$patient/$study";
 my ($f) = File::Util->new();
 $f->make_dir($path) if (! -e $path);
 foreach my $series(@_) {
  my @tokens = split /,/, $series;
  my $series_uid = substr $tokens[0], 1, -1;
  print " $series_uid \n";
  my $url = $base . "/query/getImage?SeriesInstanceUID=$series_uid";
  my $series_zip = execute_get_image($url, $key);
  my $output_name = "$path/$series_uid.zip";
  print " $output_name\n";
  open OUT, ">$output_name" or die "Could not create $output_name";
  binmode OUT;
  print  OUT $series_zip;
  close OUT;
 }
}

sub process_collections {
# my $base = shift @_;
# my $key  = shift @_;
# foreach my $c(@_) {
#  print "$c\n";
#
#  my @patient_study_values = get_patient_study_values($base, $key, $c);
#  my $study_index = 101;
##  print_collection_resources($c, "PatientStudy", @patient_study_values);
#  foreach my $study (@patient_study_values) {
#   print "\n\n $study \n";
#   my @tokens = split /,/, $study;
#   my $patient_id= $tokens[1];
#   my $study_uid = $tokens[4];
#   $patient_id = substr $patient_id, 1, -1;
#   $study_uid  = substr $study_uid, 1, -1;
#   print "$patient_id, $study_uid \n";
#   my @series_values = get_series_values($base, $key, $c, $study_uid);
#   process_series($base, $key, $patient_id, $study_index++, @series_values);
#  }
#
##  my @series_values = get_series_values($base, $key, $c);
##  print_collection_resources($c, "Series", @series_values);
# }
 die "process_collections";
}
sub extract_one_patient_id {
 my $patient_study_count = scalar (@_);
 die "Expected exactly one row in this array; found $patient_study_count" if ($patient_study_count != 1);

 my $study = shift @_;
 my @tokens = split /,/, $study;
 my $patient_id = substr $tokens[1], 1, -1;
 return $patient_id;
}

sub process_by_uid {
  my ($output_folder, $url, $key, $uid) = @_;
  my ($collection, $patient_id);
  my @patient_study_values = get_patient_study_values($url, $key, $collection, $patient_id, $uid);
  $patient_id = extract_one_patient_id(@patient_study_values);
  my $study_index = 101;
  my @series_values = get_series_values($url, $key, $collection, $uid);
  process_series($output_folder, $url, $key, $patient_id, $study_index++, @series_values);

  exit(0);
}
sub process_by_patient {
  my ($output_folder, $url, $key, $patient_id, $collection) = @_;
  my $study_uid;
  my @patient_study_values = get_patient_study_values($url, $key, $collection, $patient_id, $study_uid);
  my $study_index = 101;
  print_collection_resources($collection, "PatientStudy", @patient_study_values);

  foreach my $study (@patient_study_values) {
   print "\n\n $study \n";
   my @tokens = split /,/, $study;
   my $patient_id= $tokens[1];
   my $study_uid = $tokens[4];
   $patient_id = substr $patient_id, 1, -1;
   $study_uid  = substr $study_uid, 1, -1;
   print "$patient_id, $study_uid \n";
   my @series_values = get_series_values($url, $key, $collection, $study_uid);
   process_series($output_folder, $url, $key, $patient_id, $study_index++, @series_values);
  }

 exit(0);
}
sub process_by_collection {
  my ($output_folder, $url, $key, $collection) = @_;
  my ($patient_id, $study_uid);
  my @patient_study_values = get_patient_study_values($url, $key, $collection, $patient_id, $study_uid);
  my $study_index = 101;
  print_collection_resources($collection, "PatientStudy", @patient_study_values);
  foreach my $study (@patient_study_values) {
   print "\n\n $study \n";
   my @tokens = split /,/, $study;
   my $patient_id= $tokens[1];
   my $study_uid = $tokens[4];
   $patient_id = substr $patient_id, 1, -1;
   $study_uid  = substr $study_uid, 1, -1;
   print "$patient_id, $study_uid \n";
   my @series_values = get_series_values($url, $key, $collection, $study_uid);
   process_series($output_folder, $url, $key, $patient_id, $study_index++, @series_values);
  }

 exit(0);
}


my $base="https://services.cancerimagingarchive.net/services/v3";
my $resource="TCIA";
my $url = "$base/$resource";
my $endpoint="query/getCollectionValues";
my $key="d436c648-7ea4-40a1-8e76-9d358dd58bef";


my ($collection, $patient_id, $study_uid, $help, $output_folder);
GetOptions(
  'c:s'   => \$collection,
  'p:s'   => \$patient_id,
  'u:s'   => \$study_uid,
  'h'     => \$help,
#  'out=s' => \$output_folder,
);

$output_folder = $ARGV[0];
print_help() if (($help) || (! $output_folder));

initialize_http();

# Each function below runs and then exits
# If we do not run any of the functions, then we print the help message.

process_by_uid        ($output_folder, $url, $key, $study_uid)  if ($study_uid);
process_by_patient    ($output_folder, $url, $key, $patient_id, $collection) if ($patient_id);
process_by_collection ($output_folder, $url, $key, $collection) if ($collection);

# None of the conditions that trigger data gathering were triggered.
print_help();

