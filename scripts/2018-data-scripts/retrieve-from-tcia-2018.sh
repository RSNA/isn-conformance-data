#!/bin/sh

OUTPUT_BASE=$1
echo $OUTPUT_BASE

touch $OUTPUT_BASE
rm -r $OUTPUT_BASE
mkdir -p $OUTPUT_BASE

perl ../tcia/tcia_get_images.pl -p C3L-00277    -u 1.3.6.1.4.1.14519.5.2.1.2857.3273.184862055846930271614754681036 $OUTPUT_BASE
perl ../tcia/tcia_get_images.pl -p C3N-00953    -u 1.3.6.1.4.1.14519.5.2.1.7085.2626.192997540292073877946622133586 $OUTPUT_BASE
perl ../tcia/tcia_get_images.pl -p TCGA-G4-6304 -u 1.3.6.1.4.1.14519.5.2.1.3023.4017.246199836259881483055596634768 $OUTPUT_BASE

