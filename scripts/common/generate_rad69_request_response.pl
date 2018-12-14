#!/usr/bin/perl

use strict;
use warnings;

# Generate the XML for RAD 69 request and response
# Input argument is the working folder for submission files

sub check_args {
 if (scalar(@_) != 3) {
  my $msg = "Arguments: Folder <Rep Id> <Test Id>\n" .
            "           Folder:  Path to folder that contains images.txt.\n" .
            "                    Will be the folder where we write output files.\n" .
            "           Rep Id:  Repository Unique Id\n" .
            "           Test Id: Test Id goes in the testplan file (e.g. ids_2018-4810a)\n";
  die $msg;
 }
}

sub read_file {
 my ($path) = @_;

 open my $fh, "<", $path or die "Could not open: $path";

 my @lines;
 while (my $l = <$fh>) {
  chomp $l;
  push(@lines, $l);
 }
 close $fh;
 return @lines;
}

sub hash_uid_elements {
 my $position = shift @_;

 my %hash;
 for my $line(@_) {
  my @tokens = split /:/, $line;
  my $uid = $tokens[$position];
  $hash{$uid} = $uid;
 }
 return %hash;
}

sub array_uid_elements {
 my $position = shift @_;

 my @array;
 for my $line(@_) {
  my @tokens = split /:/, $line;
  my $uid = $tokens[$position];
  push(@array, $uid);
 }
 return @array;
}

sub check_study_uids {
 my (%uids) = @_;
 my @keys = keys %uids;
 my $key_count = scalar(@keys);
 die "Should be exactly one Study Instance UID; found $key_count\n" if ($key_count != 1);
}

sub extract_instances {
 my ($series, @uid_list) = @_;

 my @rtn_uids;

 my @array_uid_elements;
 for my $line(@uid_list) {
  my @tokens = split /:/, $line;
  push (@rtn_uids, $tokens[2]) if ($tokens[1] eq $series);
 }
 return @rtn_uids;
}

sub generate_request {
 my ($path, $rep_uid, $test_id, @uid_list) = @_;

 open my $fh, ">", $path or die "Could not open: $path";
 print $fh
       "<xdsiB:RetrieveImagingDocumentSetRequest\n" .
       "  xmlns:xdsiB=\"urn:ihe:rad:xdsi-b:2009\">\n";

 my %hash_study_uids    = hash_uid_elements(0, @uid_list);
 my %hash_series_uids   = hash_uid_elements(1, @uid_list);
 my %hash_instance_uids = hash_uid_elements(2, @uid_list);

 check_study_uids(%hash_study_uids);

 my @study_uids = keys %hash_study_uids;
 my $study = $study_uids[0];

 my @series_uids = keys %hash_series_uids;
 print $fh
       "    <xdsiB:StudyRequest studyInstanceUID=\"$study\">\n";

 for my $series(@series_uids) {
  print $fh
        "      <xdsiB:SeriesRequest seriesInstanceUID=\"$series\">\n";
  my @instance_uids = extract_instances($series, @uid_list);
  for my $instance(@instance_uids) {
   print $fh
         "         <xdsb:DocumentRequest xmlns:xdsb=\"urn:ihe:iti:xds-b:2007\">\n"   .
         "            <xdsb:RepositoryUniqueId>$rep_uid</xdsb:RepositoryUniqueId>\n" .
         "            <xdsb:DocumentUniqueId>$instance</xdsb:DocumentUniqueId>\n"   .
         "         </xdsb:DocumentRequest>\n";
#   print "$study $series $instance \n";
  }
  print $fh
        "      </xdsiB:SeriesRequest>\n";
 }
 print $fh
       "    </xdsiB:StudyRequest>\n" .
       "    <xdsiB:TransferSyntaxUIDList>\n" .
       "      <xdsiB:TransferSyntaxUID>1.2.840.10008.1.2.1</xdsiB:TransferSyntaxUID>\n" .
       "    </xdsiB:TransferSyntaxUIDList>\n" .
       "</xdsiB:RetrieveImagingDocumentSetRequest>\n";
 close $fh;
}

sub write_response_header {
 my ($fh, $rep_uid, $test_id, @uid_list) = @_;

 print $fh 
       "<TestPlan>\n" .
       "  <Test>$test_id/validate-R</Test>\n" .
       "  <TestStep id=\"validate-rad69-response\">\n" .
       "    <Goal>Correct RetrieveDocumentSetResponse values</Goal>\n" .
       "    <Standard>\n" .
       "      <ResponseBody>\n" .
       "        <xdsb:RetrieveDocumentSetResponse\n" .
       "          xmlns:xdsb=\"urn:ihe:iti:xds-b:2007\">\n" .
       "          <rs:RegistryResponse xmlns:rs=\"urn:oasis:names:tc:ebxml-regrep:xsd:rs:3.0\"\n" .
       "            status=\"urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Success\" />\n" ;
}

sub write_response_tail {
 my ($fh, $rep_uid, $test_id, @uid_list) = @_;

 print $fh 
       "        </xdsb:RetrieveDocumentSetResponse>\n" .
       "      </ResponseBody>\n" .
       "    </Standard>\n" .
       "    <XmlDetailTransaction>\n" .
       "      <Assertions>\n" .
       "        <Assert id=\"Returned doc(s)\" process=\"sameRetImgs\">\n" .
       "          <TestResponse testDir=\"../Rad69RetrieveRequest\" step=\"retrieve\" />\n" .
       "        </Assert>\n" .
       "      </Assertions>\n" .
       "    </XmlDetailTransaction>\n" .
       "  </TestStep>\n" .
       "</TestPlan>\n" ;
}

sub write_response_item {
 my ($fh, $rep_uid, $test_id, $uid) = @_;

 print $fh
       "          <xdsb:DocumentResponse>\n" .
       "            <xdsb:RepositoryUniqueId>$rep_uid</xdsb:RepositoryUniqueId>\n" .
       "            <xdsb:DocumentUniqueId>$uid</xdsb:DocumentUniqueId>\n" .
       "            <xdsb:mimeType>application/dicom</xdsb:mimeType>\n" .
       "            <xdsb:Document>\n" .
       "              <xop:Include xmlns:xop=\"http://www.w3.org/2004/08/xop/include\"\n" .
       "                href=\"cid:docxx\@ihexds.nist.gov\" />\n" .
       "            </xdsb:Document>\n" .
       "          </xdsb:DocumentResponse>\n";
}

sub generate_response {
 my ($path, $rep_uid, $test_id, @uid_list) = @_;

 open my $fh, ">", $path or die "Could not open: $path";
 write_response_header($fh, $rep_uid, $test_id, @uid_list);

 my @instance_uids = array_uid_elements(2,  @uid_list);
 foreach my $uid(@instance_uids) {
  write_response_item($fh, $rep_uid, $test_id, $uid);
 }

 write_response_tail($fh, $rep_uid, $test_id, @uid_list);


 close $fh;
}


check_args(@ARGV);

my $input_file     = "$ARGV[0]/images.txt";
my $output_request = "$ARGV[0]/rad69-request.xml";
my $output_response= "$ARGV[0]/rad69-response-testplan.xml";
my $rep_uid        = $ARGV[1];
my $test_id        = $ARGV[2];
my @uid_list = read_file($input_file);

generate_request ($output_request,  $rep_uid, $test_id, @uid_list);
generate_response($output_response, $rep_uid, $test_id, @uid_list);
