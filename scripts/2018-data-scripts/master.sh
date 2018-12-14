#!/bin/sh

BASE=/opt/image-formation
TEMP=$BASE/temp-2018
FINAL=$BASE/final-2018
CACHE=/opt/xdsi/master-environment/ImageCache-2018
TEST_BASE=/opt/xdsi/test-cases-2018

STATUS=master-status.txt

my_exit () {
 echo Could not execute $1
 exit 1
}

time ./retrieve-from-tcia-2018.sh $TEMP

echo `date` "Script begin" > $STATUS

./C3L-00277.sh $TEMP $FINAL $CACHE $TEST_BASE
rc=$?;if [[ $rc != 0 ]]; then my_exit C3L-00277.sh; fi

echo `date` "C3L-00277 complete" >> $STATUS

./C3N-00953.sh $TEMP $FINAL $CACHE $TEST_BASE
rc=$?;if [[ $rc != 0 ]]; then my_exit C3N-00953.sh; fi

echo `date` "C3N-00953 complete" >> $STATUS

./TCGA-G4-6304.sh $TEMP $FINAL $CACHE $TEST_BASE
rc=$?;if [[ $rc != 0 ]]; then my_exit TCGA-G4-6304.sh; fi

echo `date` "TCGA-G4-6304 complete" >> $STATUS

echo `date` "Script complete" >> $STATUS
