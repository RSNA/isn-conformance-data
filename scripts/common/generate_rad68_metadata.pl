#!/usr/bin/perl

use strict;
use warnings;

our ($next_id);
sub print_help {
  print "Usage: <input/output folder> <xml file> <image file> [<image file 2>]\n";
  print "       Folder needs to contain kos-selftest.dcm\n";
  print "       This script adds metadata.xml\n";
  print "       XML file contains Procedure Code Sequence\n";
  print "       Image file for one sample image\n";
  print "       A second image file is optional to give access to a different modality\n";
  exit(1);
}

sub check_inputs {
 my ($folder, $xml_file) = @_;
 my $kos = "$folder/kos-selftest.dcm";

 die "Folder does not exist: $folder" if ! -e $folder;
 die "KOS file does not exist: $kos"  if ! -e $kos;

 die "XML file does not exist: $xml_file" if ! -e $xml_file;
}

sub read_document {
 my $file = shift @_;

 my $document = do {
  local $/ = undef;
  open my $fh, "<", $file
     or die "could not open $file: $!";
  <$fh>;
 };
 return $document;
}

sub replace_variables_in_text {
 my ($template, %hash) = @_;
 my @keys = keys %hash;
 for my $key(@keys) {
  my $val = $hash{$key};
  $template =~ s/$key/$val/g;
 }
 return $template;
}

sub write_output {
 my ($file, $doc) = @_;

 open my $out, ">", $file
  or die "could not open $file: $!";
 print $out $doc;
 close $out;
}

sub map_modality_code_to_meaning {
 my ($modality) = @_;
 my %modality_hash = (
    CR     => "Computed Radiography",
    CT     => "Computed Tomography",
    DX     => "Digital Radiography",
    MG     => "Mammography",
    MR     => "Magnetic Resonance Imaging",
    OT     => "Other",
 );

 my $str = $modality_hash{$modality};
 $str = "Unknown modality" if ! $str;
 return $str;
}

sub map_body_part_to_code_and_meaning {
 my ($body_part) = @_;

 my %body_part_hash = (
    CHEST  => "T-D3000:Chest:2.16.840.1.113883.6.96",
    KIDNEY => "T-71000:Kidney:2.16.840.1.113883.6.96",
 );

 my $lookup = $body_part_hash{$body_part};
    $lookup = $body_part_hash{"CHEST"} if ! $lookup;

 my @values = split /:/, $lookup;
 return @values;
}

sub make_kos_xml {
 my ($folder) = @_;
 my $kos_dcm = "$folder/kos-selftest.dcm";
 my $kos_xml = "$folder/kos-selftest.xml";

 return if -e $kos_xml;

 my $x = "dcm2xml -B -I $kos_dcm > $kos_xml";
 `$x`;
 die "Could not execute: $x" if $?
}

sub get_dicom_element {
 my ($folder, $xsl, $default) = @_;

 make_kos_xml($folder);
 my $xml_file = "$folder/kos-selftest.xml";

 my $x = "xsltproc $xsl $xml_file";
 my $y = `$x`;
 die "ERROR: Could not execute: $x" if $?;

 $y = $default if ($y eq "");
 return $y;
}

sub make_image_xml {
 my ($image_xml, $image_dcm) = @_;

 my $x = "dcm2xml -B -I $image_dcm > $image_xml";
 `$x`;
 die "Could not execute: $x" if $?
}

sub get_dicom_element_from_image {
 my ($image_file, $xsl) = @_;
 my $xml_file = "/tmp/image.xml";

 make_image_xml($xml_file, $image_file);

 my $x = "xsltproc $xsl $xml_file";
 my $y = `$x`;
 die "ERROR: Could not execute: $x" if $?;
 return $y;
}

sub get_dicom_study_date_time {
 my ($folder) = @_;

 my $study_date = get_dicom_element($folder, "xsl/dicom-study-date.xsl", "20110404");
 my $study_time = get_dicom_element($folder, "xsl/dicom-study-time.xsl", "135000");
 return substr ($study_date . $study_time, 0, 14);
}

sub get_dicom_patient_id {
 my ($folder) = @_;

 return get_dicom_element($folder, "xsl/dicom-patient-id.xsl", "No Patient ID");
}

sub get_kos_instance_uid {
 my ($folder) = @_;

 return get_dicom_element($folder, "xsl/dicom-instance-uid.xsl", "No UID");
}

sub construct_accession_number {
 my ($folder) = @_;

 return get_dicom_element($folder, "xsl/dicom-accession-number.xsl", "No Accession Number");
}


sub get_dicom_patient_name {
 my ($folder) = @_;

 return 
	get_dicom_element($folder, "xsl/dicom-patient-family-name.xsl", "Family")
	. "^" .
	get_dicom_element($folder, "xsl/dicom-patient-given-name.xsl", "Given");
}

sub apply_xsl {
 my ($xml_file, $xsl) = @_;

 my $x   = "xsltproc $xsl $xml_file";
 print "$x\n";
 my $y   = `$x`;
 die "ERROR: Could not execute: $x" if $?;
 return $y;
}

sub get_procedure_code_sequence {
 my ($folder, $xml_file) = @_;

 my $code    = apply_xsl($xml_file, "xsl/dicom-procedure-code_code.xsl");
 my $desig   = apply_xsl($xml_file, "xsl/dicom-procedure-code_designator.xsl");
 my $meaning = apply_xsl($xml_file, "xsl/dicom-procedure-code_meaning.xsl");
 return ($code, $desig, $meaning);
}

sub construct_source_patient_info {
 my ($folder) = @_;
 my $patient_id   = get_dicom_patient_id($folder);
 my $patient_name = get_dicom_patient_name($folder);
 my $patient_dob  = get_dicom_element($folder, "xsl/dicom-patient-dob.xsl", "19990101");
 my $patient_sex  = get_dicom_element($folder, "xsl/dicom-patient-sex.xsl", "M");

 my $source_patient_info= "
               <rim:Value>PID-3|LOCAL_PATIENT_ID^^^&amp;1.3.6.1.4.1.21367.1800.13.20.1000&amp;ISO</rim:Value>
               <rim:Value>PID-5|PATIENT_NAME</rim:Value>
               <rim:Value>PID-7|PATIENT_DOB</rim:Value>
               <rim:Value>PID-8|PATIENT_SEX</rim:Value>
               <rim:Value>PID-11|100 Main St^^Metropolis^Il^44130^USA</rim:Value>
";

 $source_patient_info =~ s/LOCAL_PATIENT_ID/$patient_id/g;
 $source_patient_info =~ s/PATIENT_NAME/$patient_name/g;
 $source_patient_info =~ s/PATIENT_DOB/$patient_dob/g;
 $source_patient_info =~ s/PATIENT_SEX/$patient_sex/g;

 return $source_patient_info;
}

sub map_local_patient_id {
 my ($local_id) = @_;

 my %identifier_hash = (
    "C3L-00277"    => "IDS_2018-4801a",
    "C3N-00953"    => "IDS_2018-4801b",
    "TCGA-G4-6304" => "IDS_2018-4801c",
 );

 my $mapped_id = $identifier_hash{$local_id};
 die "Unable to map Patient ID $local_id to identifier for Affinity Domain" if (! $mapped_id) ;

 return $mapped_id;
}

sub construct_patient_id {
 my ($folder) = @_;
 my $patient_id   = map_local_patient_id(get_dicom_patient_id($folder));
 my $suffix       = "^^^&amp;1.3.6.1.4.1.21367.2005.13.20.1000&amp;ISO";

 return $patient_id . $suffix;
}

sub construct_documententry_uniqueid {
 my ($folder) = @_;
 my $instance_uid = get_kos_instance_uid($folder);

# return "urn:oid:" . $instance_uid;
 return "" . $instance_uid;
}

# Typically for objectType="urn:uuid:7edca82f-054d-47f2-a032-9b2a5b5186c1"
# FIX
sub construct_documententry_id {
 my ($folder) = @_;

 return "urn:uuid:" . "fdbcbda9-d9c9-4a19-9e1d-ffd1e869ddf1";
}

sub construct_next_id {
 $next_id++;
 return "id_" . $next_id;
}

sub construct_event_code_modality {
 my ($folder, $xml_file, $image_file) = @_;

 return "" if (! $image_file);

 my $modality          = get_dicom_element_from_image($image_file, "xsl/dicom-modality.xsl");
 my $modality_meaning  = map_modality_code_to_meaning($modality);

 my $identifier = construct_next_id();
 my $xml =
'
         <rim:Classification classificationScheme="urn:uuid:2c6b8cb7-8b2a-4051-b291-b1ae6a575ef4"
               classifiedObject="Document01" nodeRepresentation="' . $modality . '" id="' . $identifier . '">
            <rim:Slot name="codingScheme">
               <rim:ValueList>
                  <rim:Value>1.2.840.10008.2.6.1</rim:Value>
               </rim:ValueList>
            </rim:Slot>
            <rim:Name>
               <rim:LocalizedString value="' . $modality_meaning . '"/>
            </rim:Name>
         </rim:Classification>
';
}

sub construct_event_code_body_part {
 my ($folder, $xml_file, $image_file) = @_;

 my $body_part =
	get_dicom_element_from_image($image_file, "xsl/dicom-body-part-examined.xsl");
 my ($code, $meaning, $code_scheme) = 
	map_body_part_to_code_and_meaning($body_part);

 my $identifier = construct_next_id();
 my $xml =
'
         <rim:Classification classificationScheme="urn:uuid:2c6b8cb7-8b2a-4051-b291-b1ae6a575ef4"
               classifiedObject="Document01" nodeRepresentation="' . $code . '" id="' . $identifier . '">
            <rim:Slot name="codingScheme">
               <rim:ValueList>
                  <rim:Value>' . $code_scheme . '</rim:Value>
               </rim:ValueList>
            </rim:Slot>
            <rim:Name>
               <rim:LocalizedString value="' . $meaning . '"/>
            </rim:Name>
         </rim:Classification>
';
}

sub construct_event_code_list {
 my ($folder, $xml_file, $image_file_1, $image_file_2) = @_;

 my $event_code_modality_1  = construct_event_code_modality($folder, $xml_file, $image_file_1);
 my $event_code_modality_2  = construct_event_code_modality($folder, $xml_file, $image_file_2);
 my $event_code_body_part   = construct_event_code_body_part($folder, $xml_file, $image_file_1);
 return
    $event_code_modality_1 . "\n" .
    $event_code_modality_2 . "\n" .
    $event_code_body_part;
}


sub metadata_values {
 my ($folder, $xml_file, $image_file, $image_file_2) = @_;
 my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
 $year += 1900;
 $mon  += 1;
 my $now = sprintf("%04d%02d%02d%02d%02d%02d", $year, $mon, $mday, $hour, $min, $sec);
 my %hash;


 $hash{"VAR-NOW"} = $now;
 $hash{"VAR-SERVICESTARTTIME"}  = get_dicom_study_date_time($folder);
 $hash{"VAR-SERVICESTOPTIME"}   = get_dicom_study_date_time($folder);
 $hash{"VAR-SOURCEPATIENTID"}   = get_dicom_patient_id($folder);
 $hash{"VAR-SOURCEPATIENTINFO"} = construct_source_patient_info($folder);
 $hash{"VAR-PATIENTID"}         = construct_patient_id($folder);
 $hash{"VAR-ACCESSIONNUMBER"}   = construct_accession_number($folder);
 $hash{"VAR-DOCUMENTENTRY.UNIQUEID"} = construct_documententry_uniqueid($folder);
 $hash{"VAR-DOCUMENTENTRY.ID"}  = construct_documententry_id($folder);

 my ($proc_code_code, $proc_code_desig, $proc_code_meaning) = get_procedure_code_sequence($folder, $xml_file);
 $hash{"VAR-TYPECODE-code"}    = $proc_code_code;
 $hash{"VAR-TYPECODE-string"}  = $proc_code_meaning;
 $hash{"VAR-TYPECODE-codingScheme"} = $proc_code_desig;

 # These values defined for IHE Connectathons by Felhofer/Moore
 # This is from 2018 (spring)

 # Defined by IHE, adopted by Felhofer/Moore
 $hash{"VAR-CLASSCODE-code"}    = "IMAGES";
 $hash{"VAR-CLASSCODE-string"}  = "Images";
 $hash{"VAR-CLASSCODE-codingScheme"} = "1.3.6.1.4.1.19376.1.2.6.1";

 # Defined by HL7, adopted by Felhofer/Moore
 $hash{"VAR-CONFIDENTIALITYCODE-code"}    = "N";
 $hash{"VAR-CONFIDENTIALITYCODE-string"}  = "normal";
 $hash{"VAR-CONFIDENTIALITYCODE-codingScheme"} = "2.16.840.1.113883.5.25";

 # Defined by XDS-I
 $hash{"VAR-FORMATCODE-code"}    = "1.2.840.10008.5.1.4.1.1.88.59";
 $hash{"VAR-FORMATCODE-string"}  = "Key Object Selection Document";
 $hash{"VAR-FORMATCODE-codingScheme"} = "1.2.840.10008.2.6.1";

 # Defined by LOINC, adopted by Felhofer/Moore
 $hash{"VAR-HEALTHCAREFACILITYTYPECODE-code"}    = "35971002";
 $hash{"VAR-HEALTHCAREFACILITYTYPECODE-string"}  = "Ambulatory care site";
 $hash{"VAR-HEALTHCAREFACILITYTYPECODE-codingScheme"} = "2.16.840.1.113883.6.96";

 # Defined by Felhofer/Moore
 $hash{"VAR-PRACTICESETTINGCODE-code"}    = "Practice-A";
 $hash{"VAR-PRACTICESETTINGCODE-string"}  = "Radiology";
 $hash{"VAR-PRACTICESETTINGCODE-codingScheme"} = "1.3.6.1.4.1.21367.2017.3";

 $hash{"VAR-EVENTCODELIST"}                = construct_event_code_list($folder, $xml_file, $image_file, $image_file_2);

 # Defined by Felhofer/Moore
 $hash{"VAR-CONTENTTYPECODE-code"}         = "UNSPECIFIED-CONTENT-TYPE";
 $hash{"VAR-CONTENTTYPECODE-string"}       = "Unspecified Clinical Activity";
 $hash{"VAR-CONTENTTYPECODE-codingScheme"} = "1.3.6.1.4.1.21367.2017.3";

 $hash{"VAR-AUTHORROLE"}             = "Radiologist";
 $hash{"VAR-AUTHORSPECIALTY"}        = "Radiology";
 return %hash;
}

# Main starts here
my $arg_count = scalar @ARGV;

print_help if ($arg_count != 3 && $arg_count != 4);

my $folder   = $ARGV[0];
my $xml_file = $ARGV[1];
my $image_file_1 = $ARGV[2];
my $image_file_2 = $ARGV[3];
check_inputs($folder, $xml_file);

my (%hash_values);
my ($metadata_template, $metadata_modified);
my ($testplan_template, $testplan_modified);

$next_id=100;
%hash_values       = metadata_values($folder, $xml_file, $image_file_1, $image_file_2);
# Generate self test data first
$metadata_template = read_document("templates/prb-metadata-selftest.xml");
$metadata_modified = replace_variables_in_text($metadata_template, %hash_values);
                     write_output("$folder/metadata-selftest.xml", $metadata_modified);

$testplan_template = read_document("templates/prb-testplan-selftest.xml");
$testplan_modified = replace_variables_in_text($testplan_template, %hash_values);
                     write_output("$folder/testplan-selftest.xml", $testplan_modified);

# Now, generate validation data
$metadata_template = read_document("templates/prb-metadata-evaluate.xml");
$metadata_modified = replace_variables_in_text($metadata_template, %hash_values);
                     write_output("$folder/metadata-evaluate.xml", $metadata_modified);

