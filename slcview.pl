#!/usr/bin/perl -w
#
#   slcview.pl - makes a clustergram from .cdt (and .gtr, .atr if present) file
#   Copyright (C) 2002,2003 Swaine Chen (slchen@users.sourceforge.net)
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#   If this program helps you in your research and you publish images which
#   you've used slcview.pl to create, please cite:
#     S.L. Chen, unpublished.  http://slcview.sourceforge.net
#
############################################################################

# if no commands, print help screen and exit
if (!(defined $ARGV[0])) { &printhelp; }

use Image::Magick;
use Slcview;
use Getopt::Long;
&Getopt::Long::Configure("pass_through");

# Initialize some variables first

my %options;
my $outfile = '';
my $force = 0;
my $haveweights = 0;
my $havegid = 0;
my $haveaid = 0;
my $gweightfield = -1;
my $gorderfield = -1;
my $namefield = -1;
my @genenames = ();
my @arraynames = ();
my @gweight = ();
my ($printhelp, $printcolors, $printfonts, $printgnu) = (0, 0, 0, 0);

GetOptions (
  'o=s' => \$outfile,
  'f' => \$force,
  'poscolor=s' => \$options{poscolor},
  'negcolor=s' => \$options{negcolor},
  'absentcolor=s' => \$options{absentcolor},
  'colorscale=s' => \$options{colorscale},
  'xsize=f' => \$options{xsize},
  'ysize=f' => \$options{ysize},
  'width=i' => \$options{width},
  'height=i' => \$options{height},
  'noimage' => \$noimage,
  'legend=s' => \$options{legend},
  'legsize=i' => \$options{legsize},
  'legnumber=i' => \$options{legnumber},
  'title=s' => \$options{title},
  'titleheight=i' => \$options{titleheight},
  'titlefontsize=i' => \$options{titlefontsize},
  'gtrresolution=i' => \$options{gtrresolution},
  'genelabels=i' => \$options{genelabels},
  'atrresolution=i' => \$options{atrresolution},
  'arraylabels=i' => \$options{arraylabels},
  'font=s' => \$options{font},
  'spacing=i' => \$options{spacing},
  'bgcolor|backgroundcolor=s' => \$options{bgcolor},
  'linecolor=s' => \$options{linecolor},
  'help' => \$printhelp,
  'listcolors|printcolors' => \$printcolors,
  'listfonts|printfonts' => \$printfonts,
  'listgnu|printgnu' => \$printgnu
);

# do help commands first, which will short circuit everything else
if ($printhelp) { &printhelp; }
if ($printcolors) { &Slcview::printcolors; }
if ($printfonts) { &Slcview::printfonts; }
if ($printgnu) { &Slcview::printgnu; }

%options = set_options (%options);

if (!$force && -e $outfile) {
  print STDOUT "$outfile exists, overwrite? (y/N) ";
  $response = <STDIN>;
  if ($response !~ m/^y/i) { exit (1); }
}

# Parse the .cdt file on STDIN or as $ARGV[0]
# any command line options should have been removed by GetOptions, so using
# $ARGV[0] should be ok...
# if we're on STDIN then assume we have no gtr or atr file

if (defined $ARGV[0]) {
  if ($ARGV[0] =~ m/\.cdt$/) {
    $gtrfile = $ARGV[0];
    $gtrfile =~ s/cdt$/gtr/;
    $atrfile = $gtrfile;
    $atrfile =~ s/gtr$/atr/;
  } else {
    $gtrfile = $ARGV[0].'.gtr';
    $atrfile = $ARGV[0].'.atr';
  }
} else {
  $gtrfile = '';
  $atrfile = '';
}
if (!-e $gtrfile) { $options{gtrresolution} = 0; }
if (!-e $atrfile) { $options{atrresolution} = 0; }
@in = <>;
$i = 0;		# $i is a row index in the next loop, $j is a column index
foreach $line (@in) {
  chomp $line;
  $line =~ s/\r//g;
  @a = split /\t/, $line;
  if ($line =~ m/(^GID)|(NAME)|(GWEIGHT)|(GORDER)/) {
    $j = 0;
    $special = 1;
    while ($special) {
      if ($a[$j] eq 'GID') {
        $gidfield = $j;
        $havegid = 1;
        ++$j; ++$j;		# skip the UNIQID field which should be next
        next;
      }
      if ($j == 0 && !$havegid) {
        ++$j; next;		# in case no GID skip UNIQID (first field)
      }
      if ($a[$j] eq 'NAME') { $namefield = $j; ++$j; next; }
      if ($a[$j] eq 'GWEIGHT') { $gweightfield = $j; ++$j; next; }
      if ($a[$j] eq 'GORDER') { $gorderfield = $j; ++$j; $special = 0; next; }
      $special = 0;	# GORDER should be last special field, if no GORDER
			# then we're done
    }
    while ($j <= $#a) {
      push @arraynames, $a[$j];
      push @datafields, $j;
      ++$j;
    }
    next;
  }
  if ($line =~ m/EWEIGHT/) {
    @weights = @a[@datafields];
    $haveweights = 1;
    next;
  }
  if ($line =~ m/^AID/) {
    $haveaid = 1;
    foreach $j (0 .. $#datafields) {
      $aorder{$a[$datafields[$j]]} = $j;
    }
    next;
  }
  @{'row'.$i} = @a[@datafields];
  if ($gweightfield >= 0) { $gweight[$i] = $a[$gweightfield]; }
  if ($namefield >= 0) { $genenames[$i] = $a[$namefield]; }
  if ($havegid) {
    $gorder{$a[$gidfield]} = $i;
  }
  ++$i;
}

if (!$haveaid) { $options{atrresolution} = 0; }
$cols = scalar @datafields;
$rows = $i;

# adjust parameters further if needed - autoscaling, things that we don't have
# data to draw, etc.
if ($options{width} == -1) {
  $options{width} = sprintf "%i", $cols * $options{xsize};
} else {
  $options{xsize} = $options{width}/$cols;
}
if ($options{height} == -1) {
  $options{height} = sprintf "%i", $rows * $options{ysize};
} else {
  $options{ysize} = $options{height}/$rows;
}

if ($options{gtrresolution} < 0) {
  $options{gtrresolution} = int ($options{height}/2);
}
if ($options{atrresolution} < 0) {
  $options{atrresolution} = int ($options{width}/2);
}

if (!$haveweights) {
  foreach $i (0 .. $#datafields) { $weights[$i] = 1; }
}
if ($options{xsize} < $options{mintextsize}) { $options{arraylabels} = 0; }
if ($options{ysize} < $options{mintextsize}) { $options{genelabels} = 0; }
if ($options{arraylabels} < 0) {
  $options{arraylabels} = label_scale(\@arraynames, $options{xsize});
}
if ($options{genelabels} < 0) {
  $options{genelabels} = label_scale(\@genenames, $options{ysize});
}

# The actual drawing - always make an image file to simplify putting them
# together.  If there is no image to draw, make it 0 height or 0 width.
# Clustergram
if (!$noimage) {
  @d = ();
  foreach $r (0 .. $rows-1) {
    push @d, @{'row'.$r};
  }
  $clustergram = Image::Magick->new;
  $clustergram = draw_heatmap(\@d, $rows, $cols, %options);
}
# Gene tree
if ($options{gtrresolution} > 0) {
  open GTR, $gtrfile;
  @gtr = <GTR>;
  close GTR;
  $gtrimage = new Image::Magick;
  $gtrimage = draw_tree (\@gtr, \%gorder, $options{gtrresolution}, $options{height}, %options);
}
# Array tree
if ($options{atrresolution} > 0) {
  open ATR, $atrfile;
  @atr = <ATR>;
  close ATR;
  $atrimage = new Image::Magick;
  $atrimage = draw_tree (\@atr, \%aorder, $options{atrresolution}, $options{width}, %options);
  $atrimage->Flip;
  $atrimage->Rotate(90);
}
# Gene labels
if ($options{genelabels} > 0) {
  $glabimage = new Image::Magick;
  $glabimage = draw_labels (\@genenames, $options{genelabels}, $options{height}, %options);
}
# Array labels
if ($options{arraylabels} > 0) {
  $alabimage = new Image::Magick;
  $alabimage = draw_labels (\@arraynames, $options{arraylabels}, $options{width}, %options);
  $alabimage->Rotate(degrees=>270);
}
# Legend
if ($options{legend} ne '') {
  $legimage = new Image::Magick;
  $legimage = draw_legend (\@d, $rows, $cols, %options);
  $legimage->Write(filename=>$options{legend}, dither=>'False');
}

# put together the gene tree, clustergram, and gene labels first
# then put on the array tree and array labels on top
# first have to figure out what pieces there are
# images will be put together like this:
#
# -------------
# |     8     |
# -------------
# |   | 2 |   |		1 = $ulspacer
# | 1 |---| 4 |		2 = $atrimage
# |   | 3 |   |		3 = $alabimage
# |---|---|---|		4 = $urspacer
# |   |   |   |		5 = $gtrimage
# | 5 | 6 | 7 |		6 = $clustergram
# |   |   |   |		7 = $glabimage
# -------------         8 = $titleimage
# We will put 5,6,7 together first, then make 1 and 4 the right size, then
#   put together 2 and 3, then add 1 and 4, then put it all together with 8.
# Also need to add spacing between 5-6, 6-7, 2-3, and 3-6.
# Images 5, 6, 7 should be same height.
# Images 2, 3, 6 should be same width.
# 1 and 4 will change based on whether some of the others are missing and
#   on $options{spacing}.

my $ul_width = 0;
my $ul_height = 0;
my $ur_width = 0;
my $ur_height = 0;

if ($noimage) {

  $gtr_out_image = new Image::Magick;
  $atr_out_image = new Image::Magick;
  use File::Basename;
  my ($outname, $outpath, $outsuffix) = fileparse($outfile);
  if (!defined $outpath) { $outpath = ""; }
  if (!defined $outsuffix) { $outsuffix = ""; }

  $gtr_out_image = stack_LR ($options{spacing}, $options{bgcolor}, $gtrimage, $glabimage);
  $gtr_out_image->Write(filename=>$outpath.'gtr.'.$outname.$outsuffix, dither=>'False');
  $atr_out_image = stack_TB ($options{spacing}, $options{bgcolor}, $atrimage, $alabimage);
  $atr_out_image->Write(filename=>$outpath.'atr.'.$outname.$outsuffix, dither=>'False');

} else {	# if ($noimage)

  # first generate $ulspacer and $urspacer
  $ul_height = 0;
  $ul_height = $options{atrresolution} + $options{arraylabels};
  if ($options{atrresolution} > 0 && $options{arraylabels} > 0) {
    $ul_height += $options{spacing};
  }
  $ur_height = $ul_height;
  $ul_width = $options{gtrresolution};
  $ur_width = $options{genelabels};

  if ($ul_width && $ul_height) {
    $ulspacer = new Image::Magick;
    $ulspacer->Read("xc:$options{bgcolor}");
    $ulspacer->Scale($ul_width.'x'.$ul_height.'!');
  }
  if ($ur_width && $ur_height) {
    $urspacer = new Image::Magick;
    $urspacer->Read("xc:$options{bgcolor}");
    $urspacer->Scale($ur_width.'x'.$ur_height.'!');
  }

  $topmiddle = new Image::Magick;
  $topmiddle = stack_TB ($options{spacing}, $options{bgcolor}, $atrimage, $alabimage);

  $top_image = new Image::Magick;
  $top_image = stack_LR ($options{spacing}, $options{bgcolor}, $ulspacer, $topmiddle, $urspacer);

  $bot_image = new Image::Magick;
  $bot_image = stack_LR ($options{spacing}, $options{bgcolor}, $gtrimage, $clustergram, $glabimage);

  $out_image = new Image::Magick;
  $out_image = stack_TB ($options{spacing}, $options{bgcolor}, $top_image, $bot_image);
  if ($options{title} ne '') {
    # Title
    $titleimage = new Image::Magick;
    $titleimage->Read("xc:$options{bgcolor}");
    $titleimage->Scale($out_image->Get('width')."x".$options{titleheight}."!");
    # we're just going to start writing from the top left, but leave 10% space
    $titleimage->Annotate(fill=>$options{linecolor}, font=>$options{font}, pointsize=>$options{titlefontsize}, text=>$options{title}, x=>(0.1*$out_image->Get('width')), y=>(0.9*$options{titleheight}));
    $out_image = stack_TB ($options{spacing}, $options{bgcolor}, $titleimage, $top_image, $bot_image);
  }

  $out_image->Write(filename=>$outfile, dither=>'False');

}

#-----------------------
# subroutines below here
#

sub label_scale {
  my ($labels, $boxsize) = @_;
  my @len = ();
  my $mean = 0;
  my $stdev = 0;

  # do auto-detection of $xres for draw_labels if needed - try to make it
  # long enough for mean length of label + 1 standard deviation
  foreach my $lab (@$labels) {
    push @len, length $lab;
  }
  # calculate mean and stdev
  foreach my $len (@len) {
    $mean += $len;
  }
  $mean /= scalar @len;
  foreach my $len (@len) {
    $stdev += ($len - $mean)*($len - $mean);
  }
  $stdev /= scalar @len;
  $stdev = sqrt ($stdev);
  return (int ($boxsize * $mean));
}

sub stack_LR {
  my ($spacing, $color, @pieces) = @_;
  my $index = 0;
  my $height = 0;
  my $piece;
  my $image = new Image::Magick;
  my $spacer;
  $image->Set(Adjoin=>'True');

  return (undef) if !scalar @pieces;	# no images given
  $piece = shift @pieces;
  while (!defined $piece || !defined ($piece->Get('width'))) {
    last if !scalar @pieces;
    $piece = shift @pieces;
  }

  if (defined $piece) {
    $height = $piece->Get('height');
    return ($height) if ($height <= 0);
    $image->[$index] = $piece;

    while ($piece = shift @pieces) {
      if (defined $piece && $piece->Get('width') > 0) {
        if ($piece->Get('height') == $height) {
          $spacer = new Image::Magick;
          $spacer->Read("xc:$color");
          $spacer->Scale($spacing.'x'.$height.'!');
          ++$index;
          $image->[$index] = $spacer;
          ++$index;
          $image->[$index] = $piece;
        } else {
          return (-1);		# not all images were the same height;
        }
      }
    }
    if ($index > 0) {
      return ($image->Append(stack=>'False'));
    } else {
      return ($image->[0]);
    }
  } else {
    return (undef);			# no good images found
  }
}


sub stack_TB {
  my ($spacing, $color, @pieces) = @_;
  my $index = 0;
  my $width = 0;
  my $piece;
  my $image = new Image::Magick;
  my $spacer;
  $image->Set(Adjoin=>'True');

  return (undef) if !scalar @pieces;	# no images given
  $piece = shift @pieces;
  while (!defined $piece || !defined ($piece->Get('height'))) {
    last if !scalar @pieces;
    $piece = shift @pieces;
  }

  if (defined $piece) {
    $width = $piece->Get('width');
    return ($width) if ($width <= 0);
    $image->[$index] = $piece;

    while ($piece = shift @pieces) {
      if (defined $piece && $piece->Get('height') > 0) {
        if ($piece->Get('width') == $width) {
          $spacer = new Image::Magick;
          $spacer->Read("xc:$color");
          $spacer->Scale($width.'x'.$spacing.'!');
          ++$index;
          $image->[$index] = $spacer;
          ++$index;
          $image->[$index] = $piece;
        } else {
          return (-1);		# not all images were the same height;
        }
      }
    }
    if ($index > 0) {
      return ($image->Append(stack=>'True'));
    } else {
      return ($image->[0]);
    }
  } else {
    return (undef);			# no good images found
  }
}


sub printhelp {
format help =
Usage: slcview.pl <cdt file> -o <output file> [ Options ]
Options, which may be shortened to any unique abbreviation, are:

  -f
    Force, do not prompt to overwrite output file.

  -xsize <float>
    Width (pixels) of each small colored box in the clustergram.  Numbers
    greater than 1 and less than 1 are both allowed.  Defaults to 3.

  -ysize <float>
    Height (pixels) of each small colored box in the clustergram.  Numbers
    greater than 1 and less than 1 are both allowed.  Defaults to 3.

  -width <integer>
    Width of the entire clustergram in pixels.  This is equivalent to xsize
    multiplied by the number of columns/experiments.  This overrides xsize.

  -height <integer>
    Height of the entire clustergram in pixels.  This is equivalent to ysize
    multiplied by the number of rows/genes.  This overrides ysize.

  -noimage
    Tells slcview to not draw the clustergram image file.  Will only give you
    a gene tree and an array tree, depending on whether those files are
    present.  You should still specify a .cdt file, though.  For example, if
    your file is foo.gtr, you should specify foo.cdt and it will find your
    foo.gtr file.  The files it creates will be based on the output filename
    you specify, with a "gtr." or "atr." prepended to the filename.

  -legend <legend filename>
    Tells slcview to draw a legend image so you know what the scale is for the
    colors used in the clustergram.

  -legsize <integer>
    The size of the square boxes in the legend diagram, in pixels.  Similar to
    xsize and ysize, but for the legend diagram instead.  Unlike xsize and
    ysize, -legsize makes squares only, and -legsize must be an integer.  Does
    nothing if you don't specify a legend filename with the -legend parameter.
    Defaults to 20.

  -legnumber <integer>
    The number of legend boxes you want to draw.  These will span the full
    range of colors used in the diagram, so if you specify -legnumber 3 then
    you will only get the brightest negative, black, and the brightest positive
    color in the legend.  Defaults to 10.

  -atrresolution <integer>
    The height of the array tree diagram in pixels.  The width of the array
    tree diagram is automatically set to the same width as the clustergram.
    If you specify 0, no array tree will be drawn.  If you specify a negative
    number, it will adjust the height based on the number of arrays you have.
    This is the default behavior (-1).

  -arraylabels <integer>
    The height of the section devoted to labels for the arrays.  The width
    is automatically set to the same width as the clustergram.  If you
    specify 0, no array labels will be drawn.  If you specify a negative
    number, the program will try to find a height that will allow most of
    the labels to be drawn.  This is the default (-1).  If xsize ends up
    being less than 6, no labels will be drawn either because the text
    would be too small.

  -gtrresolution <integer>
    The width of the gene tree diagram in pixels.  The height of the gene tree
    diagram is automatically set to the same height as the clustergram.
    If you specify 0, no gene tree will be drawn.  If you specify a negative
    number, it will adjust the height based on the number of genes you have.
    This is the default behavior (-1).

  -genelabels <integer>
    The width of the section devoted to labels for the genes.  The height
    is automatically set to the same height as the clustergram.  If you
    specify 0, no gene labels will be drawn.  If you specify a negative
    number, the program will try to find a width that will allow most of
    the labels to be drawn.  This is the default (-1).  If ysize ends up
    being less than 6, no labels will be drawn either because the text
    would be too small.

  -title <string>
    Title to draw on top of the final image.  The two options -titleheight
    and -titlefontsize really need to be specified.  If this is not set,
    no title will be drawn.

  -titleheight <integer>
    The height of the title area on top of the final image.  In pixels.
    Has no effect if -title is not specified.

  -titlefontsize <float>
    The font size of the title text.  This should probably not be greater
    than -titleheight in pixels.

  -spacing <integer>
    The number of pixels to separate the tree diagrams from the clustergram.
    Defaults to 5.

  -poscolor <color>
    Color (string or RGB hex in the form #xxxxxx) for positive values.
    Defaults to red.

  -negcolor <color>
    Color (string or RGB hex in the form #xxxxxx) for negative values.
    Defaults to "lime" (careful - green is only half-saturated according to
    ImageMagick; lime is what you get from #00ff00, which most consider green).

  -absentcolor <color>
    The color for absent data points.  Defaults to gray.

  -colorscale <median|mean|max>
  -colorscale <float>
    How to set the scale for color intensity.  The first three options (median,
    mean, max) base it on the data.  The last option takes a number and uses
    that as the scale regardless of what the data is.  This number should be 
    positive.

  -bgcolor <color>
    The background color for the diagram.  Defaults to white.

  -linecolor <color>
    The color of the lines in the tree diagram and all text labels.  You can
    use a color name or RGB hex numbers (i.e. #00ff00 for "green" (aka lime),
    #ff00ff for magenta).  Defaults to black.

  -help
    Print out this message.

  -gnu
    Print out GNU GPL Terms and Conditions and Warranty information.

Valid color strings can be obtained by running 'slcview.pl -listcolors'.
Valid font names can be obtained by running 'slcview.pl -listfonts'.

slcview version 2.0.  Copyright (C) 2002 Swaine Chen
slcview comes with ABSOLUTELY NO WARRANTY.  This is free software, and you
are welcome to redistribute it under certain conditions.  For details
type 'slcview.pl -gnu'.

.
$~ = "help";
write;
exit(-1);
}
