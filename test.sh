#!/bin/bash
echo "Checking for libraries used by slcview.pl..."
echo "Perl is a required scripting/programming language."
echo "The next test will print out the version of Perl installed on your system."
echo "-----BEGIN test for Perl-----[1m"
perl --version
echo "[0m-----END test for Perl-----"
echo
echo "ImageMagick is a required library, which contains the 'convert' command."
echo "The next test will print the version of convert installed on your system."
echo "-----BEGIN test for ImageMagick/convert utility-----[1m"
convert --help | grep Version
echo "[0m-----END test for ImageMagick/convert utility-----"
echo
echo "The Perl API for ImageMagick is required."
echo "The next test will see if the PerlMagick libraries are installed properly."
echo "-----BEGIN test for PerlMagick-----[1m"
perl -e 'use Image::Magick; print "PerlMagick libraries seem to work ok!\n" if new Image::Magick;'
echo "[0m-----END test for PerlMagick-----"
echo
echo "GhostScript is a recommended library.  It allows slcview.pl to draw text labels."
echo "The next test will print the version of GhostScript installed on your system."
echo "Note that if you have GhostScript installed but PerlMagick doesn't know"
echo "about it/can't use it for some reason, then slcview.pl will still be unable"
echo "to draw text labels."
echo "-----BEGIN test for GhostScript-----[1m"
gs --version
echo "[0m-----END test for GhostScript-----"
echo
echo "The next tests will test the functioning of slcview.pl."
echo "If you see no error messages between the BEGIN and END lines below,"
echo "then all tests passed."
echo
echo "-----BEGIN slcview.pl tests-----[1m"
echo
./slcview.pl test/foo.cdt -pos red -neg lime -absent gray -line black -bg white -font Helvetica -gtrresolution 0 -atrresolution 0 -xsize 3 -ysize 3 -genelabels 0 -arraylabels 0 -spacing 5 -legend test/legend.gif -legsize 20 -legnumber 10 -o test/clustergram.gif -f
cmp test/test.clustergram.gif test/clustergram.gif
cmp test/test.legend.gif test/legend.gif
./slcview.pl test/foo.cdt -pos red -neg lime -line black -bg white -absent gray -font Helvetica -noimage -gtrresolution -1 -atrresolution -1 -genelabels -1 -arraylabels 0 -xsize 10 -ysize 10 -spacing 5 -o test/trees.gif -f
cmp test/test.gtr.trees.gif test/gtr.trees.gif
cmp test/test.atr.trees.gif test/atr.trees.gif

echo "[0m-----END slcview.pl tests-----"
echo
echo "If there were any differences in the files, you can try the following"
echo "commands to view the two files at once.  Most of the time, if slcview.pl"
echo "ran without screenfuls of errors, the images will be identical except for"
echo "one or two characters, which may be just header information, as the"
echo "images themselves are still identical."
echo
echo "Since you need to have ImageMagick installed to use slcview.pl, you"
echo "should be able to use the following commands (assuming you're running X):"
echo "  $ display test/clustergram.gif &"
echo "  $ display test/test.clustergram.gif &"
echo "This should bring up two windows, one with the .gif file generated on"
echo "your machine, and one with the test .gif file so you can visually"
echo "compare them yourself."
echo
echo "Note that the test/gtr.trees.gif and test/legend.gif files generated"
echo "require that GhostScript be installed so that slcview.pl can write"
echo "text labels.  The files test/atr.trees.gif and test/clustergram.gif"
echo "that are generated should work without GhostScript."
echo
echo "Tests done."
