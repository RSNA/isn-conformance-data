#!/bin/sh

if [ $# -ne 1 ]
then
 echo "Arguments: <folder>"
 exit 1
fi

if [ -e $1 ]
 then
  echo Removing existing folder: $1
  rm -r $1
 fi
echo Creating new folder: $1
mkdir -p $1

