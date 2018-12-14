use Env qw(XDSI);
use File::Copy;
use File::Path qw(make_path);

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

sub process_folder {
  my ($input_folder, $target_folder) = @_;
  mkdir ($target_folder) if (! -e $target_folder);
  @images = read_images($input_folder);

  my $file = "$target_folder/images.txt";
  open my $out, ">>", "$file" or die "Could not create output file: $file";

  foreach $i(@images) {
    print "$input_folder/$i\n";
    my ($study_uid, $series_uid, $instance_uid, $xfer_syntax) = extract_uids("$input_folder/$i");
    print $out "$study_uid:$series_uid:$instance_uid\n";
    print      "$study_uid:$series_uid:$instance_uid\n";
  }
  close $out;
}


# Main starts here

$count = scalar(@ARGV);
die "Arguments: source_folder target_folder" if ($count != 2);

@input_folders = read_folder($ARGV[0]);
foreach $f(@input_folders) {
 print "$f\n";
 process_folder("$ARGV[0]/$f", $ARGV[1]);
}
