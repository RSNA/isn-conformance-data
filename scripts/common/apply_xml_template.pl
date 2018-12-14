#!/usr/bin/perl

sub print_help_and_die {
 my $msg =
  "Arguments: <Input Folder> <Output Folder> <template file> <max>\n" .
  "           <template file> is an XML file that modifies DICOM element values\n" .
  "           <max> is the maximum number of files to process\n";
 die $msg;

}
sub check_args {
 my ($arg_count) = scalar(@_);
 print_help_and_die() if ($arg_count != 4);
}


sub read_folder {
 my ($path) = @_;

 opendir(D, $path) || die "ERROR: Could not open folder: $path"; my @list = grep !/^\.\.?$/, readdir(D); closedir D;
 return @list;
}


 check_args(@ARGV);
 my ($input_folder, $output_folder, $template_file, $max) = @ARGV;
 my @files = read_folder($input_folder);
 my $index = 1;

 foreach $f(@files) {
  print "$f\n";

  my $x = "xml2dcm -i $input_folder/$f -o $output_folder/$f -x $template_file";
  my $y = `$x`;
  if ($?) {
    print "Could not execute: $x\n";
    print "$y\n";
    die;
  }
  if ($index++ >= $max) {
   print "Hit maximum number of files: $max\n";
   exit();
  }
 }

