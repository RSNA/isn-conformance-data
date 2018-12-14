#!/bin/sh

if [ $# -ne 4 ]
then
 echo "Arguments: <input folder> <output folder> <master cache> <test base>"
 exit 1
fi

BASE=$1/C3N-00953/101
TEMP_1=$1/temp-1
TEMP_1a=$1/temp-1a
TEMP_2=$1/temp-2
TEMP_3=$1/temp-3
OUTPUT_IMAGES=$2/images/C3N-00953
OUTPUT_SUBMISSION=$2/submission-data/C3N-00953
IMAGE_CACHE=$3
TEST_BASE=$4
ACCESSION_NUMBER=2794663908550664
TEMPLATE=templates/CT-Abdomen-Pelvis_WO-W-contrast.xml
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
echo $TEMP_1 $TEMP_1a
ls $TEMP_1a
 perl ../common/apply_xml_template.pl $TEMP_1a $TEMP_2 $TEMPLATE 5
echo $TEMP_2; ls $TEMP_2
 perl ../common/rename_dicom_files.pl $TEMP_2 $TEMP_3
echo $TEMP_3; ls $TEMP_3
done

pushd $TEMP_3
tar cf - $ACCESSION_NUMBER/1/*.dcm | (cd $OUTPUT_IMAGES; tar xf -)
echo $OUTPUT_IMAGES; ls $OUTPUT_IMAGES
tar cf - $ACCESSION_NUMBER/2/*.dcm | (cd $OUTPUT_IMAGES; tar xf -)
echo $OUTPUT_IMAGES; ls $OUTPUT_IMAGES
tar cf - $ACCESSION_NUMBER/4/*.dcm | (cd $OUTPUT_IMAGES; tar xf -)
echo $OUTPUT_IMAGES; ls $OUTPUT_IMAGES
popd

mkkos \
        --title DCM-113030 \
        --retrieve-aet DCM4CHEE \
        --location-uid 1.3.6.1.4.1.21367.13.80.110 \
        -o $OUTPUT_SUBMISSION/kos-selftest.dcm \
		$OUTPUT_IMAGES/$ACCESSION_NUMBER/1 \
		$OUTPUT_IMAGES/$ACCESSION_NUMBER/2 \
		$OUTPUT_IMAGES/$ACCESSION_NUMBER/4

mkkos \
        --title DCM-113030 \
        --retrieve-aet DCM4CHEE \
        --location-uid 1.3.6.1.4.1.21367.13.80.110 \
        -o $OUTPUT_SUBMISSION/kos-evaluate.dcm \
		$OUTPUT_IMAGES/$ACCESSION_NUMBER/1 \
		$OUTPUT_IMAGES/$ACCESSION_NUMBER/2 \
		$OUTPUT_IMAGES/$ACCESSION_NUMBER/4

perl ../common/extract_uids.pl $OUTPUT_IMAGES/$ACCESSION_NUMBER $OUTPUT_SUBMISSION
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

perl ../common/generate_rad68_metadata.pl	\
	$OUTPUT_SUBMISSION	\
	$TEMPLATE $OUTPUT_IMAGES/$ACCESSION_NUMBER/1/1.dcm
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

perl ../common/generate_rad69_request_response.pl $OUTPUT_SUBMISSION $REPO_ID ids_2018-4803b
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

cp      $OUTPUT_SUBMISSION/metadata-selftest.xml \
        $TEST_BASE/ids_2018-4801b/SelftestPnR
cp      $OUTPUT_SUBMISSION/kos-selftest.dcm \
        $TEST_BASE/ids_2018-4801b/SelftestPnR
cp      $OUTPUT_SUBMISSION/testplan-selftest.xml \
        $TEST_BASE/ids_2018-4801b/SelftestPnR/testplan.xml

cp      $OUTPUT_SUBMISSION/metadata-evaluate.xml \
        $TEST_BASE/ids_2018-4801b/ValidateMetadata
cp      $OUTPUT_SUBMISSION/kos-evaluate.dcm \
        $TEST_BASE/ids_2018-4801b/ValidateKOS

cp      $OUTPUT_SUBMISSION/images.txt \
        $TEST_BASE/ids_2018-4802b/Rad55RetrieveRequest

cp      $OUTPUT_SUBMISSION/rad69-request.xml \
        $TEST_BASE/ids_2018-4803b/Rad69RetrieveRequest
cp      $OUTPUT_SUBMISSION/rad69-response-testplan.xml \
        $TEST_BASE/ids_2018-4803b/ValidateRad69Response/testplan.xml

# Make output files in ImageCache area

../common/clean_make_folder.sh	\
	 $IMAGE_CACHE/sim/ids-repository/1.3.6.1.4.1.14519.5.2.1.7085.2626.192997540292073877946622133586
perl ../common/create_ids_repository_files.pl \
	$OUTPUT_IMAGES/$ACCESSION_NUMBER	\
	$IMAGE_CACHE/sim/ids-repository

../common/clean_make_folder.sh $IMAGE_CACHE/std/2018/C3N-00953/images
../common/copy_images_to_std_area.sh	\
	$OUTPUT_IMAGES/$ACCESSION_NUMBER \
	$IMAGE_CACHE/std/2018/C3N-00953/images

