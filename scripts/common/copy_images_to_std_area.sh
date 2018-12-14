#!/bin/sh

my_exit() {
 echo Unable to copy $1 $2
 exit 1
}

if [ $# -ne 2 ]
then
 echo "Arguments: <input folder> <output folder>"
 exit 1
fi


INPUT=$1
OUTPUT=$2

a=1000
for z in $INPUT/*/*; do
 echo $a $z $OUTPUT/$a.dcm
 cp $z $OUTPUT/$a.dcm
 rc=$?; if [[ $rc != 0 ]]; then my_exit $z $OUTPUT/$a.dcm; fi
 a=$(($a + 1))
done
