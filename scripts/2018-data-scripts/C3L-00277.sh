#!/bin/sh

if [ $# -ne 4 ]
then
 echo "Arguments: <input folder> <output folder> <master cache> <test base>"
 exit 1
fi

BASE=$1/C3L-00277/101
TEMP_1=$1/temp-1
TEMP_1a=$1/temp-1a
TEMP_2=$1/temp-2
TEMP_3=$1/temp-3
OUTPUT_IMAGES=$2/images/C3L-00277
OUTPUT_SUBMISSION=$2/submission-data/C3L-00277
IMAGE_CACHE=$3
TEST_BASE=$4
ACCESSION_NUMBER=5347639127757044
TEMPLATE=templates/XR_Chest_2_Views.xml
REPO_ID=1.3.6.1.4.1.21367.13.80.110

../common/clean_make_folder.sh $TEMP_3
../common/clean_make_folder.sh $OUTPUT_IMAGES
../common/clean_make_folder.sh $OUTPUT_SUBMISSION

for z in $BASE/*zip; do
 ../common/clean_make_folder.sh $TEMP_1
 ../common/clean_make_folder.sh $TEMP_1a
 ../common/clean_make_folder.sh $TEMP_2

 unzip -d $TEMP_1 -q $z
 perl ../common/reduce_image.pl $TEMP_1 $TEMP_1a
 perl ../common/apply_xml_template.pl $TEMP_1a $TEMP_2 $TEMPLATE 5
 perl ../common/rename_dicom_files.pl $TEMP_2 $TEMP_3
done

pushd $TEMP_3
tar cf - $ACCESSION_NUMBER/5398/1.dcm | (cd $OUTPUT_IMAGES; tar xf -)
popd

mkkos \
	--title DCM-113030 \
	--retrieve-aet DCM4CHEE \
	--location-uid 1.3.6.1.4.1.21367.13.80.110 \
	-o $OUTPUT_SUBMISSION/kos-selftest.dcm $OUTPUT_IMAGES/$ACCESSION_NUMBER/5398

mkkos \
	--title DCM-113030 \
	--retrieve-aet DCM4CHEE \
	--location-uid 1.3.6.1.4.1.21367.13.80.110 \
	-o $OUTPUT_SUBMISSION/kos-evaluate.dcm $OUTPUT_IMAGES/$ACCESSION_NUMBER/5398

perl ../common/extract_uids.pl $OUTPUT_IMAGES/$ACCESSION_NUMBER $OUTPUT_SUBMISSION
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

perl ../common/generate_rad68_metadata.pl $OUTPUT_SUBMISSION $TEMPLATE \
	$OUTPUT_IMAGES/$ACCESSION_NUMBER/5398/1.dcm
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

perl ../common/generate_rad69_request_response.pl $OUTPUT_SUBMISSION $REPO_ID ids_2018-4803a
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

cp	$OUTPUT_SUBMISSION/metadata-selftest.xml \
	$TEST_BASE/ids_2018-4801a/SelftestPnR
cp	$OUTPUT_SUBMISSION/kos-selftest.dcm \
	$TEST_BASE/ids_2018-4801a/SelftestPnR
cp	$OUTPUT_SUBMISSION/testplan-selftest.xml \
	$TEST_BASE/ids_2018-4801a/SelftestPnR/testplan.xml

cp	$OUTPUT_SUBMISSION/metadata-evaluate.xml \
	$TEST_BASE/ids_2018-4801a/ValidateMetadata
cp	$OUTPUT_SUBMISSION/kos-evaluate.dcm \
	$TEST_BASE/ids_2018-4801a/ValidateKOS

cp      $OUTPUT_SUBMISSION/images.txt \
	$TEST_BASE/ids_2018-4802a/Rad55RetrieveRequest

cp      $OUTPUT_SUBMISSION/rad69-request.xml \
        $TEST_BASE/ids_2018-4803a/Rad69RetrieveRequest
cp      $OUTPUT_SUBMISSION/rad69-response-testplan.xml \
        $TEST_BASE/ids_2018-4803a/ValidateRad69Response/testplan.xml

# Make output files in ImageCache area

../common/clean_make_folder.sh  \
         $IMAGE_CACHE/sim/ids-repository/1.3.6.1.4.1.14519.5.2.1.2857.3273.184862055846930271614754681036
perl ../common/create_ids_repository_files.pl \
        $OUTPUT_IMAGES/$ACCESSION_NUMBER \
        $IMAGE_CACHE/sim/ids-repository

../common/clean_make_folder.sh $IMAGE_CACHE/std/2018/C3L-00277/images
../common/copy_images_to_std_area.sh    \
        $OUTPUT_IMAGES/$ACCESSION_NUMBER \
        $IMAGE_CACHE/std/2018/C3L-00277/images
