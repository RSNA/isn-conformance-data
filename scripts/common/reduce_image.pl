use Env qw(XDSI);
use File::Copy;
use File::Path qw (make_path rmtree);

sub read_folder {
  my ($folder) = (@_);
  opendir (my $dh, $folder) or die "Could not open folder: $folder";
  @entries = grep { !/^\./ && -d "$folder/$_" } readdir($dh);
  close $dh;
  return @entries;
}

sub read_images {
  my ($folder) = (@_);
  opendir (my $dh, "$folder") or die "Could not open images folder: $folder";
  @entries = grep { !/^\./ && -f "$folder/$_" } readdir($dh);
  close $dh;
  return @entries;
}

sub extract_field {
 my ($s, $index) = (@_);
 my @tokens = split(" ", $s);
 my $x = $tokens[$index];
 my $len = length $x;
 my $y = substr($x, 1, $len-2);
 return $y;
}

sub extract_one_field {
 my ($path, $field) = @_;
  my ($path) = (@_);
  my $tmp = "/tmp/x.txt";
  my $x = "dcmdump -w 200 $path > $tmp";
  die "Could not execute $x" if `$x` != 0;
  my $x1 = "grep -i '$field' $tmp";
  my $x1a = `$x1`;
  my $x1b = extract_field($x1a, 4);
  return $x1b;
}


sub extract_uids {
  my ($path) = (@_);
  my $xfer_syntax = extract_one_field($path, "0002,0010");
  my $study_uid = extract_one_field($path,   ": (0020,000D");
  my $series_uid = extract_one_field($path,  "0020,000E");
  my $instance_uid = extract_one_field($path, "0008,0018");
  return ($study_uid, $series_uid, $instance_uid, $xfer_syntax);
}

sub extract_image_params {
  my ($path) = (@_);
  my $rows = extract_one_field($path, "0028,0010");
  my $cols = extract_one_field($path, "0028,0011");
  my $bits = extract_one_field($path, "0028,0100");
  return ($rows, $cols, $bits);
}

sub write_rows_xml {
  my ($file, $rows) = @_;
  open my $out, ">", "$file" or die "Could not create output file: $file";
  my $template =
	"<?xml version=\"1.0\" encoding=\"UTF-8\"?><NativeDicomModel xml:space=\"preserve\">\n" .
	" <DicomAttribute keyword=\"Rows\" tag=\"00280010\" vr=\"US\">\n" .
	"  <Value number=\"1\">ROWS_VALUE</Value>\n" .
	" </DicomAttribute>\n" .
	"</NativeDicomModel>\n";
  $template =~ s/ROWS_VALUE/$rows/;
  print $out $template;
  close $out;
}

sub extract_full_pixels {
  my ($file, $folder) = @_;

  rmtree   ($folder);
  make_path($folder);
  my $x = " dcm2xml -c -d $folder - < $file";
  `$x`;
  die "Could not execute $x" if $?;
  my @bulk_files = read_images($folder);
  my $bulk_count = scalar(@bulk_files);
  die "Wrong number of bulk files in $folder\n" if ($bulk_count != 1);
  return "$folder/$bulk_files[0]";
}

sub extract_reduced_pixels {
  my ($output_file, $input_file, $rows, $cols, $bits) = @_;

  die "Cannot handle bits/pixel $bits" if ($bits != 8 && $bits != 16);
  my $bytes_to_read = $rows * $cols;
  $bytes_to_read *= 2 if ($bits == 16);
  print "Bytes to read: $bytes_to_read\n";

  open my $fh, "<:raw", "$input_file" or die "Could not open full pixels: $input_file\n";
  my $bytes_read = read $fh, my $bytes, $bytes_to_read;
  die "Read $bytes_read but expected $bytes_to_read" unless $bytes_read == $bytes_to_read;
  close $fh;

  open my $output_fh, ">", "$output_file" or die "Could not open output pixel file: $output_file";
  binmode $output_fh;
  print $output_fh $bytes;
  close $output_fh;
}

sub extract_xml_and_bulk_data {
  my ($input_image, $xml_file, $bulk_folder) = @_;

  rmtree   ($bulk_folder);
  make_path($bulk_folder);

  my $x = "dcm2xml -I -c -d $bulk_folder - < $input_image > $xml_file";
  `$x`;
  die "Could not execute $x\n" if $?;
}

sub read_file {
  my ($input_file) = @_;
  open FH, "<", $input_file or die "Could not open $input_file for reading\n";

  my @lines;
  while (my $x = <FH>) {
    push (@lines, $x);
  }
  close FH;
  return @lines;
}

sub write_file {
  my ($output_file, @lines) = @_;
  open FH, ">", $output_file or die "Could not open $output_file for writing\n";

  foreach my $line(@lines) {
    print FH $line;
  }
  close FH;
}

sub modify_image_xml_file {
  my ($output_xml, $input_xml, $rows, $cols, $bits) = @_;
  my @xml = read_file($input_xml);
  my $modified_length = $rows * $cols;
  $modified_length *= 2 if ($bits == 16);

#  my $line_count = scalar @xml;
#  print "Line count: $line_count\n";


  my @modified_xml;
  my $substitute_in_row = 0;
  my $match;
  my $substitution;
  foreach my $x (@xml) {
    if ($substitute_in_row == 0) {
      push (@modified_xml, $x);

      if ($x =~ m/00280010/) {
#        my $rows_value = "<Value number=\"1\">$rows</Value>\n";
#        push (@modified_xml, $rows_value);
        $substitute_in_row = 1;
        $match = ">\\d+<";
        $substitution=">$rows<";
      } elsif ($x =~ m/7FE00010/) {
        print "Bulk data\n";
        $substitute_in_row = 1;
        $match = "length=\\d+";
        $substitution="length=$modified_length";
      } else {
        $substitute_in_row = 0;
      }
    } else {
      print "$x\n";
      $x =~ s/$match/$substitution/;
      print "$x\n";
      push (@modified_xml, $x);
      $substitute_in_row = 0;
    }
  }
  write_file($output_xml, @modified_xml);
}

sub write_new_image {
  my ($output_image, $image_xml, $rows, $cols, $bits) = @_;
  my $modified_xml = $image_xml . "-tmp";

  modify_image_xml_file($modified_xml, $image_xml, $rows, $cols, $bits);

  my $x = "xml2dcm -x $modified_xml -o $output_image";
  `$x`;
  die "Could not execute $x\n" if $?;
}

sub process_image {
  my ($input_image, $target_image) = @_;
  my ($rows, $cols, $bits) = extract_image_params("$input_image");
  print "Rows $rows columns $cols bits allocated $bits\n";
  my $new_rows = int($rows / 4);
  extract_xml_and_bulk_data($input_image, "/tmp/image.xml", "/tmp/pixels");
  write_new_image($target_image, "/tmp/image.xml", $new_rows, $cols, $bits);
}

sub process_folder {
  my ($input_folder, $target_folder) = @_;
  mkdir ($target_folder) if (! -e $target_folder);
  @images = read_images($input_folder);

  foreach $i(@images) {
    print "$input_folder/$i\n";
    process_image("$input_folder/$i", "$target_folder/$i");
  }
}


# Main starts here

$count = scalar(@ARGV);
die "Arguments: source_folder target_folder" if ($count != 2);

process_folder($ARGV[0], $ARGV[1]);
