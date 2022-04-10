#!/usr/bin/perl
#
#   Slcview.pm - Perl Module containing functions used by slcview.pl 
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
#   you've used slcview.pl or Slcview.pm to create, please cite:
#     S.L. Chen, unpublished.  http://slcview.sourceforge.net
#
############################################################################

package Slcview;
require Exporter;
use warnings;
use strict;
use Image::Magick;
use vars qw(@ISA @EXPORT @EXPORT_OK);

@ISA = qw(Exporter);
@EXPORT = qw(draw_heatmap draw_tree draw_labels draw_legend set_options);
@EXPORT_OK = qw(draw_heatmap draw_tree draw_labels draw_legend calculate_scale set_options colornames printcolors printfonts printgnu);

# There are four procedures: draw_heatmap, draw_tree, draw_labels, and
# set_options
# The first three do what you (might) expect.  Options are passed as hashes.
# Data is passed as an array reference(s).  Next two parameters tell number of
# rows and number of columns in data.  Your data array better have
# rows x columns elements in it.
# The last, set_options, sets (surprise) default options used by the first
# three procedures which will be overridden by any options passed

sub draw_heatmap {
  my ($data, $rows, $cols, %options) = @_;
  # $data is an array reference to a flat array containing all the data
  # $rows and $cols impose a logical structure on the @$data array
  # %options is an array of options.  You should have run set_options on this
  #   before calling this procedure, as it will assume all options have been
  #   set to some value.

  my ($pr, $pg, $pb, $nr, $ng, $nb);	# working color variables
  my $scale = 0;	# the scale factor used to map data to colors
  my ($i, $j);		# generic counters
  my $pixel_color;	# holds calculated color scaled depending on data
  my $resolution;	# final resolution of image
  my $heatmap = new Image::Magick;
  my $datapoint;	# will hold one element of data array so we don't have
			#   to modify the real array

  $pr = hex(substr $options{poscolor}, 1, 2);
  $pg = hex(substr $options{poscolor}, 3, 2);
  $pb = hex(substr $options{poscolor}, 5, 2);
  $nr = hex(substr $options{negcolor}, 1, 2);
  $ng = hex(substr $options{negcolor}, 3, 2);
  $nb = hex(substr $options{negcolor}, 5, 2);

  # Draw the clustergram first

  $scale = calculate_scale ($data, $rows, $cols, $options{colorscale});

  # The actual drawing

  $heatmap->Read("xc:$options{bgcolor}");
  $heatmap->Scale(geometry=>$cols.'x'.$rows.'!');
  foreach $i (0 .. $rows-1) {
    foreach $j (0 .. $cols-1) {
      if (defined ($$data[$i*$cols + $j]) && $$data[$i*$cols + $j] ne "") {
        $datapoint = $$data[$i*$cols + $j] / $scale;
        if ($datapoint >= 0) {
          if ($datapoint > 1) { $datapoint = 1; }
          $pixel_color = sprintf "%2.2x%2.2x%2.2x", $pr*$datapoint, $pg*$datapoint, $pb*$datapoint;
        } else {
          if ($datapoint < -1) { $datapoint = -1; }
          $pixel_color = sprintf "%2.2x%2.2x%2.2x", -$nr*$datapoint, -$ng*$datapoint, -$nb*$datapoint;
        }
        $heatmap->Set("pixel[$j,$i]"=>"#".$pixel_color);
      } else {
        $pixel_color = $options{absentcolor};
        $heatmap->Set("pixel[$j,$i]"=>$pixel_color);
      }
    }
  }

  # Calculate the resolution based on width/height or xsize/ysize options.
  # Note that if set, width/height override xsize/ysize
  if ($options{width} < 0) {
    $options{width} = sprintf "%i", $cols * $options{xsize};
  }
  if ($options{height} < 0) {
    $options{height} = sprintf "%i", $rows * $options{ysize};
  }
  $resolution = $options{width}.'x'.$options{height}.'!';

  # Scale the image to the right resolution

  $heatmap->Set(dither=>'False');
  if ($options{width} < $cols || $options{height} < $rows) {
    $heatmap->Sample(geometry=>$resolution);
  } else {
    $heatmap->Scale(geometry=>$resolution);
  }

  return $heatmap;
}

sub draw_tree {
  my ($data, $node_order, $xres, $yres, %options) = @_;
  # draw the tree with nodes lined up vertically, so leaves are horizontal lines
  # xres, yres are dimensions of the final tree image
  # This will NOT add $options{spacing} to the bottom of the leaves

  my $treeimage = new Image::Magick;
  my %joined_node_x = ();	# holds x-coord of joined nodes
  my %joined_node_y = ();	# holds y-coord of joined nodes
  my $ysize = $yres/(scalar @$data + 1);	# should be close to ysize
						# use this calculation because
						# width and height override
						# xsize and ysize options
  my $line;		# generic variable to hold data array elements
  my @f;		# generic array for splitting
  my ($x0, $x1, $x2);	# x0 is where new line joining nodes is, x1 and x2 is where old nodes are
  my ($y1, $y2);	# y1 and y2 are where the nodes being joined are

  $treeimage->Read("xc:$options{bgcolor}");
  $treeimage->Scale(geometry=>$xres."x".$yres."!");
  foreach $line (@$data) {
    chomp $line;
    my @f = split /\t/, $line;
    $x0 = treex($f[3], $xres);
    if (defined $joined_node_x{$f[1]}) {
      $x1 = $joined_node_x{$f[1]};
    } else {
      $x1 = $xres - 1;		# coordinates on the image count from 0
    }
    if (defined $joined_node_x{$f[2]}) {
      $x2 = $joined_node_x{$f[2]};
    } else {
      $x2 = $xres - 1;
    }

    # if node 1 and node 2 have c1 correlation, nodes 3 and 4 have c2
    # correlation, and the joined node 1/2 and node 3/4 have c3 correlation
    # then sometimes there is an artifact where c3 < c1 or c3 < c2, which makes
    # for a not very pretty and also a little artifactual plot.  So clip this
    # so that c3 >= c1 and c3 >= c2.
    if ($x0 > $x1) { $x0 = $x1; }
    if ($x0 > $x2) { $x0 = $x2; }

    $y1 = treey($f[1], $ysize, \%$node_order, \%joined_node_y);
    $y2 = treey($f[2], $ysize, \%$node_order, \%joined_node_y);
    $joined_node_x{$f[0]} = $x0;
    $joined_node_y{$f[0]} = sprintf "%i", ($y1 + $y2)/2;

    # first the vertical line joining nodes
    $treeimage->Draw(primitive=>'line', points=>"$x0,$y1 $x0,$y2", stroke=>$options{linecolor});
    # next the two lines joining the nodes to the vertical line we just drew
    $treeimage->Draw(primitive=>'line', points=>"$x0,$y1 $x1,$y1", stroke=>$options{linecolor});
    $treeimage->Draw(primitive=>'line', points=>"$x0,$y2 $x2,$y2", stroke=>$options{linecolor});
  }

  return ($treeimage);

  ###########################
  # Subroutines for draw_tree
  ###########################
  sub treex {
    my ($correlation, $xres) = @_;

    # correlations go from -1 to +1 so change them to a 0-1 scale
    return (sprintf "%i", ($correlation + 1) / 2 * $xres - 1);
  }

  sub treey {
    my ($node, $ysize, $node_order, $joined_node) = @_;
    # node_order comes from the original .cdt file
    # joined_node holds the y-coordinate of nodes which have already been joined

    my $y;
    if ($node =~ m/(GENE)|(ARRY)/) {
      $y = sprintf "%i", $$node_order{$node} * $ysize + $ysize/2;
    } else {
      $y = $$joined_node{$node};
    }
    return ($y);
  }
}

sub draw_labels {
  my ($labels, $xres, $yres, %options) = @_;

  my $image = new Image::Magick;
  my $increment = $yres/(scalar @$labels);
  my $fontsize = int($increment);	# size of fonts should pretty much
					# be $options{ysize} or $options{xsize}
  my $i;			# generic counter variable
  my ($x, $y);			# where we're going to draw the label


  $image->Read("xc:$options{bgcolor}");
  $image->Scale($xres."x".$yres."!");
  foreach $i (0 .. $#$labels) {
    $x = 0;
    $y = int (0.5 + ($i * $increment + $increment));
    $image->Annotate(fill=>$options{linecolor}, font=>$options{font}, pointsize=>$fontsize, text=>$$labels[$i], x=>$x, y=>$y);
  }

  return $image;
}

sub draw_legend {
  my ($data, $rows, $cols, %options) = @_;
  # $data is a reference to an array containing all the data points
  # $rows, $cols refer to the logical structure of $data
  # final image will be legsize*legnumber high and 4*legsize wide

  my $image = new Image::Magick;
  my $scale = calculate_scale ($data, $rows, $cols, $options{colorscale});
  my @legend_numbers = ();
  my ($width, $height);		# image width and height
  my $i;			# generic counter variable
  my $text;			# temporary variable to hold legend text
  my ($pr, $pg, $pb, $nr, $ng, $nb);	# working color variables
  my $pixel_color;

  $pr = hex(substr $options{poscolor}, 1, 2);
  $pg = hex(substr $options{poscolor}, 3, 2);
  $pb = hex(substr $options{poscolor}, 5, 2);
  $nr = hex(substr $options{negcolor}, 1, 2);
  $ng = hex(substr $options{negcolor}, 3, 2);
  $nb = hex(substr $options{negcolor}, 5, 2);

  foreach $i (0 .. $options{legnumber}-1) {
    # the legend will give values from -1 to +1, scaled - saturated colors
    push @legend_numbers, (2*$i/($options{legnumber}-1) - 1);
  }

  # draw by pixel first
  $width = 4;
  $height = $options{legnumber};

  $image->Read("xc:$options{bgcolor}");
  $image->Scale(geometry=>$width.'x'.$height.'!');
  foreach $i (0 .. $options{legnumber}-1) {
    if ($legend_numbers[$i] >= 0) {
      $pixel_color = sprintf "%2.2x%2.2x%2.2x", $pr*$legend_numbers[$i], $pg*$legend_numbers[$i], $pb*$legend_numbers[$i];
    } else {
      $pixel_color = sprintf "%2.2x%2.2x%2.2x", -$nr*$legend_numbers[$i], -$ng*$legend_numbers[$i], -$nb*$legend_numbers[$i];
    }
    $image->Set("pixel[0,$i]"=>"#".$pixel_color);
  }

  # rescale the image to real size
  $width = 4 * $options{legsize};
  $height = $options{legnumber} * $options{legsize};
  $image->Scale(geometry=>$width.'x'.$height.'!');

  # now do the annotations
  foreach $i (0 .. $options{legnumber}-1) {
    $text = sprintf "%2.2f", $legend_numbers[$i]*$scale;
    if ($i == 0) { $text = "< $text"; }
    if ($i == $#legend_numbers) { $text = "> $text"; }
    $image->Annotate(fill=>$options{linecolor}, font=>$options{font}, pointsize=>int(0.75*$options{legsize}), text=>$text, x=>($options{legsize} + $options{spacing} - 1), y=>($i*$options{legsize} + int(7/8*$options{legsize})-1));
  }

  return $image;
}

sub calculate_scale {
  my ($data, $rows, $cols, $method) = @_;
  # $method is "mean", "median", "max", or a number for constant

  my @range = ();	# range of values in each row, needed for autoscaling
  my ($i, $j);		# generic counter variables
  my $scale;		# the value we're going to return

  foreach $i (0 .. $rows-1) {
    my $rmax = -10000;
    my $rmin = 10000;
    foreach $j (0 .. $cols-1) {
      if (defined ($$data[$i*$cols + $j]) && $$data[$i*$cols + $j] ne "") {
        if ($$data[$i*$cols + $j] > $rmax) { $rmax = $$data[$i*$cols + $j]; }
        if ($$data[$i*$cols + $j] < $rmin) { $rmin = $$data[$i*$cols + $j]; }
      }
    }
    push @range, $rmax - $rmin;
  }
  @range = sort {$a <=> $b} @range;

  if ($method eq "mean") {
    foreach my $range (@range) {
      $scale += $range;
    }
    $scale /= scalar @range;
  } elsif ($method eq "max") {
    $scale = $range[$#range];
  } elsif ($method =~ /^([+-])?(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/ && $method > 0) {
    # test if it's a valid float, use regexp from one of the O'Reilly Perl books
    # we also need it to be positive
    $scale = $method;
  } else {
    # this is last in case we don't have a valid value, use median
    if ($#range % 2 == 0) { $scale = $range[$#range/2]/2; }
    else { $scale = ($range[($#range-1)/2] + $range[($#range+1)/2]) / 2; }
  }

  return $scale;
}

sub set_options {
  my (%options) = @_;

  my $option_key;	# generic option key variable
  my %program_defaults = (
    poscolor => '255,0,0',	# red
    negcolor => '0,255,0',	# green
    absentcolor => '127,127,127',	# middle gray, gray50 according to ImageMagick
    xsize => 3,
    ysize => 3,
    width => -1,
    height => -1,
    noimage => 0,
    legend => '',
    legsize => 20,
    legnumber => 10,
    gtrresolution => -1,	# auto-scale, sort of
    genelabels => -1,		# auto-detect, sort of
    atrresolution => -1,	# auto-scale, sort of
    arraylabels => -1,		# auto-detect, sort of
    font => 'Helvetica',
    mintextsize => 6,	# if x/ysize smaller than this don't draw those labels
    spacing => 5,
    bgcolor => '255,255,255',	# white
    linecolor => '0,0,0',	# black
    colorscale => 'median',	# mean, median, max, or a number for constant
    title => ''
  );

  # read in any user/system defaults - these should set values for %defaults
  our %defaults = ();
  foreach my $conf_file ("/etc/slcview.conf", "/usr/etc/slcview.conf", "/usr/local/etc/slcview.conf",  "$ENV{HOME}/.slcviewrc") {
    if (-f $conf_file) {
      do $conf_file;
    }
  }

  # canonicalize to lower case to handle any capitalization
  foreach $option_key (keys %defaults) {
    $defaults{lc($option_key)} = $defaults{$option_key};
  }
  foreach $option_key (keys %options) {
    $options{lc($option_key)} = $options{$option_key};
  }

  # fill in options with default options if they weren't specified
  # fill with configuration file values first
  # if still not specified, use program defaults
  # handle xsize, ysize, width, height first because they are special
  if (!defined $options{width} && defined $options{xsize}) {
    $options{width} = -1;
  }
  if (!defined $options{height} && defined $options{ysize}) {
    $options{height} = -1;
  }
  foreach $option_key (keys %program_defaults) {
    if (!defined $options{$option_key}) { 
      if (!defined $defaults{$option_key}) {
        $options{$option_key} = $program_defaults{$option_key};
      } else {
        $options{$option_key} = $defaults{$option_key};
      }
    }
  }

  # collapse all the various color specification methods into one format
  foreach $option_key (qw(poscolor negcolor absentcolor bgcolor linecolor)) {
    $options{$option_key} = colornames($options{$option_key});
    # set to default if invalid color specified
    if ($options{$option_key} eq '-1') {
      $options{$option_key} = colornames($program_defaults{$option_key});
    }
  }

  return (%options);
}

sub colornames {
  my ($colorname) = @_;

  # These colors and values are taken from the ImageMagick website at
  # http://www.imagemagick.org/www/color.html

  if ($colorname =~ /^#[0-9A-Fa-f]{6}$/) {
    return $colorname;
  }
  if ($colorname =~ m/^\d+,\d+,\d+$/) {
    return sprintf ("#%2.2x%2.2x%2.2x", split (/,/, $colorname));
  }
  my $color = '-1';
  if ($colorname eq 'aliceblue') { $color = '240,248,255'; }
  elsif ($colorname eq 'antiquewhite') { $color = '250,235,215'; }
  elsif ($colorname eq 'aqua') { $color = '0,255,255'; }
  elsif ($colorname eq 'aquamarine') { $color = '127,255,212'; }
  elsif ($colorname eq 'azure') { $color = '240,255,255'; }
  elsif ($colorname eq 'beige') { $color = '245,245,220'; }
  elsif ($colorname eq 'bisque') { $color = '255,228,196'; }
  elsif ($colorname eq 'black') { $color = '0,0,0'; }
  elsif ($colorname eq 'blanchedalmond') { $color = '255,235,205'; }
  elsif ($colorname eq 'blue') { $color = '0,0,255'; }
  elsif ($colorname eq 'blueviolet') { $color = '138,43,226'; }
  elsif ($colorname eq 'brown') { $color = '165,42,42'; }
  elsif ($colorname eq 'burlywood') { $color = '222,184,135'; }
  elsif ($colorname eq 'cadetblue') { $color = '95,158,160'; }
  elsif ($colorname eq 'chartreuse') { $color = '127,255,0'; }
  elsif ($colorname eq 'chocolate') { $color = '210,105,30'; }
  elsif ($colorname eq 'coral') { $color = '255,127,80'; }
  elsif ($colorname eq 'cornflowerblue') { $color = '100,149,237'; }
  elsif ($colorname eq 'cornsilk') { $color = '255,248,220'; }
  elsif ($colorname eq 'crimson') { $color = '220,20,60'; }
  elsif ($colorname eq 'cyan') { $color = '0,255,255'; }
  elsif ($colorname eq 'darkblue') { $color = '0,0,139'; }
  elsif ($colorname eq 'darkcyan') { $color = '0,139,139'; }
  elsif ($colorname eq 'darkgoldenrod') { $color = '184,134,11'; }
  elsif ($colorname eq 'darkgray') { $color = '169,169,169'; }
  elsif ($colorname eq 'darkgreen') { $color = '0,100,0'; }
  elsif ($colorname eq 'darkgrey') { $color = '169,169,169'; }
  elsif ($colorname eq 'darkkhaki') { $color = '189,183,107'; }
  elsif ($colorname eq 'darkmagenta') { $color = '139,0,139'; }
  elsif ($colorname eq 'darkolivegreen') { $color = '85,107,47'; }
  elsif ($colorname eq 'darkorange') { $color = '255,140,0'; }
  elsif ($colorname eq 'darkorchid') { $color = '153,50,204'; }
  elsif ($colorname eq 'darkred') { $color = '139,0,0'; }
  elsif ($colorname eq 'darksalmon') { $color = '233,150,122'; }
  elsif ($colorname eq 'darkseagreen') { $color = '143,188,143'; }
  elsif ($colorname eq 'darkslateblue') { $color = '72,61,139'; }
  elsif ($colorname eq 'darkslategray') { $color = '47,79,79'; }
  elsif ($colorname eq 'darkslategrey') { $color = '47,79,79'; }
  elsif ($colorname eq 'darkturquoise') { $color = '0,206,209'; }
  elsif ($colorname eq 'darkviolet') { $color = '148,0,211'; }
  elsif ($colorname eq 'deeppink') { $color = '255,20,147'; }
  elsif ($colorname eq 'deepskyblue') { $color = '0,191,255'; }
  elsif ($colorname eq 'dimgray') { $color = '105,105,105'; }
  elsif ($colorname eq 'dimgrey') { $color = '105,105,105'; }
  elsif ($colorname eq 'dodgerblue') { $color = '30,144,255'; }
  elsif ($colorname eq 'firebrick') { $color = '178,34,34'; }
  elsif ($colorname eq 'floralwhite') { $color = '255,250,240'; }
  elsif ($colorname eq 'forestgreen') { $color = '34,139,34'; }
  elsif ($colorname eq 'fractal') { $color = '128,128,128'; }
  elsif ($colorname eq 'fuchsia') { $color = '255,0,255'; }
  elsif ($colorname eq 'gainsboro') { $color = '220,220,220'; }
  elsif ($colorname eq 'ghostwhite') { $color = '248,248,255'; }
  elsif ($colorname eq 'gold') { $color = '255,215,0'; }
  elsif ($colorname eq 'goldenrod') { $color = '218,165,32'; }
  elsif ($colorname eq 'gray') { $color = '126,126,126'; }
  elsif ($colorname eq 'gray0') { $color = '0,0,0'; }
  elsif ($colorname eq 'gray1') { $color = '3,3,3'; }
  elsif ($colorname eq 'gray10') { $color = '26,26,26'; }
  elsif ($colorname eq 'gray100') { $color = '255,255,255'; }
  elsif ($colorname eq 'gray11') { $color = '28,28,28'; }
  elsif ($colorname eq 'gray12') { $color = '31,31,31'; }
  elsif ($colorname eq 'gray13') { $color = '33,33,33'; }
  elsif ($colorname eq 'gray14') { $color = '36,36,36'; }
  elsif ($colorname eq 'gray15') { $color = '38,38,38'; }
  elsif ($colorname eq 'gray16') { $color = '41,41,41'; }
  elsif ($colorname eq 'gray17') { $color = '43,43,43'; }
  elsif ($colorname eq 'gray18') { $color = '46,46,46'; }
  elsif ($colorname eq 'gray19') { $color = '48,48,48'; }
  elsif ($colorname eq 'gray2') { $color = '5,5,5'; }
  elsif ($colorname eq 'gray20') { $color = '51,51,51'; }
  elsif ($colorname eq 'gray21') { $color = '54,54,54'; }
  elsif ($colorname eq 'gray22') { $color = '56,56,56'; }
  elsif ($colorname eq 'gray23') { $color = '59,59,59'; }
  elsif ($colorname eq 'gray24') { $color = '61,61,61'; }
  elsif ($colorname eq 'gray25') { $color = '64,64,64'; }
  elsif ($colorname eq 'gray26') { $color = '66,66,66'; }
  elsif ($colorname eq 'gray27') { $color = '69,69,69'; }
  elsif ($colorname eq 'gray28') { $color = '71,71,71'; }
  elsif ($colorname eq 'gray29') { $color = '74,74,74'; }
  elsif ($colorname eq 'gray3') { $color = '8,8,8'; }
  elsif ($colorname eq 'gray30') { $color = '77,77,77'; }
  elsif ($colorname eq 'gray31') { $color = '79,79,79'; }
  elsif ($colorname eq 'gray32') { $color = '82,82,82'; }
  elsif ($colorname eq 'gray33') { $color = '84,84,84'; }
  elsif ($colorname eq 'gray34') { $color = '87,87,87'; }
  elsif ($colorname eq 'gray35') { $color = '89,89,89'; }
  elsif ($colorname eq 'gray36') { $color = '92,92,92'; }
  elsif ($colorname eq 'gray37') { $color = '94,94,94'; }
  elsif ($colorname eq 'gray38') { $color = '97,97,97'; }
  elsif ($colorname eq 'gray39') { $color = '99,99,99'; }
  elsif ($colorname eq 'gray4') { $color = '10,10,10'; }
  elsif ($colorname eq 'gray40') { $color = '102,102,102'; }
  elsif ($colorname eq 'gray41') { $color = '105,105,105'; }
  elsif ($colorname eq 'gray42') { $color = '107,107,107'; }
  elsif ($colorname eq 'gray43') { $color = '110,110,110'; }
  elsif ($colorname eq 'gray44') { $color = '112,112,112'; }
  elsif ($colorname eq 'gray45') { $color = '115,115,115'; }
  elsif ($colorname eq 'gray46') { $color = '117,117,117'; }
  elsif ($colorname eq 'gray47') { $color = '120,120,120'; }
  elsif ($colorname eq 'gray48') { $color = '122,122,122'; }
  elsif ($colorname eq 'gray49') { $color = '125,125,125'; }
  elsif ($colorname eq 'gray5') { $color = '13,13,13'; }
  elsif ($colorname eq 'gray50') { $color = '127,127,127'; }
  elsif ($colorname eq 'gray51') { $color = '130,130,130'; }
  elsif ($colorname eq 'gray52') { $color = '133,133,133'; }
  elsif ($colorname eq 'gray53') { $color = '135,135,135'; }
  elsif ($colorname eq 'gray54') { $color = '138,138,138'; }
  elsif ($colorname eq 'gray55') { $color = '140,140,140'; }
  elsif ($colorname eq 'gray56') { $color = '143,143,143'; }
  elsif ($colorname eq 'gray57') { $color = '145,145,145'; }
  elsif ($colorname eq 'gray58') { $color = '148,148,148'; }
  elsif ($colorname eq 'gray59') { $color = '150,150,150'; }
  elsif ($colorname eq 'gray6') { $color = '15,15,15'; }
  elsif ($colorname eq 'gray60') { $color = '153,153,153'; }
  elsif ($colorname eq 'gray61') { $color = '156,156,156'; }
  elsif ($colorname eq 'gray62') { $color = '158,158,158'; }
  elsif ($colorname eq 'gray63') { $color = '161,161,161'; }
  elsif ($colorname eq 'gray64') { $color = '163,163,163'; }
  elsif ($colorname eq 'gray65') { $color = '166,166,166'; }
  elsif ($colorname eq 'gray66') { $color = '168,168,168'; }
  elsif ($colorname eq 'gray67') { $color = '171,171,171'; }
  elsif ($colorname eq 'gray68') { $color = '173,173,173'; }
  elsif ($colorname eq 'gray69') { $color = '176,176,176'; }
  elsif ($colorname eq 'gray7') { $color = '18,18,18'; }
  elsif ($colorname eq 'gray70') { $color = '179,179,179'; }
  elsif ($colorname eq 'gray71') { $color = '181,181,181'; }
  elsif ($colorname eq 'gray72') { $color = '184,184,184'; }
  elsif ($colorname eq 'gray73') { $color = '186,186,186'; }
  elsif ($colorname eq 'gray74') { $color = '189,189,189'; }
  elsif ($colorname eq 'gray75') { $color = '191,191,191'; }
  elsif ($colorname eq 'gray76') { $color = '194,194,194'; }
  elsif ($colorname eq 'gray77') { $color = '196,196,196'; }
  elsif ($colorname eq 'gray78') { $color = '199,199,199'; }
  elsif ($colorname eq 'gray79') { $color = '201,201,201'; }
  elsif ($colorname eq 'gray8') { $color = '20,20,20'; }
  elsif ($colorname eq 'gray80') { $color = '204,204,204'; }
  elsif ($colorname eq 'gray81') { $color = '207,207,207'; }
  elsif ($colorname eq 'gray82') { $color = '209,209,209'; }
  elsif ($colorname eq 'gray83') { $color = '212,212,212'; }
  elsif ($colorname eq 'gray84') { $color = '214,214,214'; }
  elsif ($colorname eq 'gray85') { $color = '217,217,217'; }
  elsif ($colorname eq 'gray86') { $color = '219,219,219'; }
  elsif ($colorname eq 'gray87') { $color = '222,222,222'; }
  elsif ($colorname eq 'gray88') { $color = '224,224,224'; }
  elsif ($colorname eq 'gray89') { $color = '227,227,227'; }
  elsif ($colorname eq 'gray9') { $color = '23,23,23'; }
  elsif ($colorname eq 'gray90') { $color = '229,229,229'; }
  elsif ($colorname eq 'gray91') { $color = '232,232,232'; }
  elsif ($colorname eq 'gray92') { $color = '235,235,235'; }
  elsif ($colorname eq 'gray93') { $color = '237,237,237'; }
  elsif ($colorname eq 'gray94') { $color = '240,240,240'; }
  elsif ($colorname eq 'gray95') { $color = '242,242,242'; }
  elsif ($colorname eq 'gray96') { $color = '245,245,245'; }
  elsif ($colorname eq 'gray97') { $color = '247,247,247'; }
  elsif ($colorname eq 'gray98') { $color = '250,250,250'; }
  elsif ($colorname eq 'gray99') { $color = '252,252,252'; }
  elsif ($colorname eq 'green') { $color = '0,128,0'; }
  elsif ($colorname eq 'greenyellow') { $color = '173,255,47'; }
  elsif ($colorname eq 'grey') { $color = '128,128,128'; }
  elsif ($colorname eq 'honeydew') { $color = '240,255,240'; }
  elsif ($colorname eq 'hotpink') { $color = '255,105,180'; }
  elsif ($colorname eq 'indianred') { $color = '205,92,92'; }
  elsif ($colorname eq 'indigo') { $color = '75,0,130'; }
  elsif ($colorname eq 'ivory') { $color = '255,255,240'; }
  elsif ($colorname eq 'khaki') { $color = '240,230,140'; }
  elsif ($colorname eq 'lavender') { $color = '230,230,250'; }
  elsif ($colorname eq 'lavenderblush') { $color = '255,240,245'; }
  elsif ($colorname eq 'lawngreen') { $color = '124,252,0'; }
  elsif ($colorname eq 'lemonchiffon') { $color = '255,250,205'; }
  elsif ($colorname eq 'lightblue') { $color = '173,216,230'; }
  elsif ($colorname eq 'lightcoral') { $color = '240,128,128'; }
  elsif ($colorname eq 'lightcyan') { $color = '224,255,255'; }
  elsif ($colorname eq 'lightgoldenrodyellow') { $color = '250,250,210'; }
  elsif ($colorname eq 'lightgray') { $color = '211,211,211'; }
  elsif ($colorname eq 'lightgreen') { $color = '144,238,144'; }
  elsif ($colorname eq 'lightgrey') { $color = '211,211,211'; }
  elsif ($colorname eq 'lightpink') { $color = '255,182,193'; }
  elsif ($colorname eq 'lightsalmon') { $color = '255,160,122'; }
  elsif ($colorname eq 'lightseagreen') { $color = '32,178,170'; }
  elsif ($colorname eq 'lightskyblue') { $color = '135,206,250'; }
  elsif ($colorname eq 'lightslategray') { $color = '119,136,153'; }
  elsif ($colorname eq 'lightslategrey') { $color = '119,136,153'; }
  elsif ($colorname eq 'lightsteelblue') { $color = '176,196,222'; }
  elsif ($colorname eq 'lightyellow') { $color = '255,255,224'; }
  elsif ($colorname eq 'lime') { $color = '0,255,0'; }
  elsif ($colorname eq 'limegreen') { $color = '50,205,50'; }
  elsif ($colorname eq 'linen') { $color = '250,240,230'; }
  elsif ($colorname eq 'magenta') { $color = '255,0,255'; }
  elsif ($colorname eq 'maroon') { $color = '128,0,0'; }
  elsif ($colorname eq 'mediumaquamarine') { $color = '102,205,170'; }
  elsif ($colorname eq 'mediumblue') { $color = '0,0,205'; }
  elsif ($colorname eq 'mediumorchid') { $color = '186,85,211'; }
  elsif ($colorname eq 'mediumpurple') { $color = '147,112,219'; }
  elsif ($colorname eq 'mediumseagreen') { $color = '60,179,113'; }
  elsif ($colorname eq 'mediumslateblue') { $color = '123,104,238'; }
  elsif ($colorname eq 'mediumspringgreen') { $color = '0,250,154'; }
  elsif ($colorname eq 'mediumturquoise') { $color = '72,209,204'; }
  elsif ($colorname eq 'mediumvioletred') { $color = '199,21,133'; }
  elsif ($colorname eq 'midnightblue') { $color = '25,25,112'; }
  elsif ($colorname eq 'mintcream') { $color = '245,255,250'; }
  elsif ($colorname eq 'mistyrose') { $color = '255,228,225'; }
  elsif ($colorname eq 'moccasin') { $color = '255,228,181'; }
  elsif ($colorname eq 'navajowhite') { $color = '255,222,173'; }
  elsif ($colorname eq 'navy') { $color = '0,0,128'; }
  elsif ($colorname eq 'none') { $color = '0,0,0'; }
  elsif ($colorname eq 'oldlace') { $color = '253,245,230'; }
  elsif ($colorname eq 'olive') { $color = '128,128,0'; }
  elsif ($colorname eq 'olivedrab') { $color = '107,142,35'; }
  elsif ($colorname eq 'orange') { $color = '255,165,0'; }
  elsif ($colorname eq 'orangered') { $color = '255,69,0'; }
  elsif ($colorname eq 'orchid') { $color = '218,112,214'; }
  elsif ($colorname eq 'palegoldenrod') { $color = '238,232,170'; }
  elsif ($colorname eq 'palegreen') { $color = '152,251,152'; }
  elsif ($colorname eq 'paleturquoise') { $color = '175,238,238'; }
  elsif ($colorname eq 'palevioletred') { $color = '219,112,147'; }
  elsif ($colorname eq 'papayawhip') { $color = '255,239,213'; }
  elsif ($colorname eq 'peachpuff') { $color = '255,218,185'; }
  elsif ($colorname eq 'peru') { $color = '205,133,63'; }
  elsif ($colorname eq 'pink') { $color = '255,192,203'; }
  elsif ($colorname eq 'plum') { $color = '221,160,221'; }
  elsif ($colorname eq 'powderblue') { $color = '176,224,230'; }
  elsif ($colorname eq 'purple') { $color = '128,0,128'; }
  elsif ($colorname eq 'red') { $color = '255,0,0'; }
  elsif ($colorname eq 'rosybrown') { $color = '188,143,143'; }
  elsif ($colorname eq 'royalblue') { $color = '65,105,225'; }
  elsif ($colorname eq 'saddlebrown') { $color = '139,69,19'; }
  elsif ($colorname eq 'salmon') { $color = '250,128,114'; }
  elsif ($colorname eq 'sandybrown') { $color = '244,164,96'; }
  elsif ($colorname eq 'seagreen') { $color = '46,139,87'; }
  elsif ($colorname eq 'seashell') { $color = '255,245,238'; }
  elsif ($colorname eq 'sienna') { $color = '160,82,45'; }
  elsif ($colorname eq 'silver') { $color = '192,192,192'; }
  elsif ($colorname eq 'skyblue') { $color = '135,206,235'; }
  elsif ($colorname eq 'slateblue') { $color = '106,90,205'; }
  elsif ($colorname eq 'slategray') { $color = '112,128,144'; }
  elsif ($colorname eq 'slategrey') { $color = '112,128,144'; }
  elsif ($colorname eq 'snow') { $color = '255,250,250'; }
  elsif ($colorname eq 'springgreen') { $color = '0,255,127'; }
  elsif ($colorname eq 'steelblue') { $color = '70,130,180'; }
  elsif ($colorname eq 'tan') { $color = '210,180,140'; }
  elsif ($colorname eq 'teal') { $color = '0,128,128'; }
  elsif ($colorname eq 'thistle') { $color = '216,191,216'; }
  elsif ($colorname eq 'tomato') { $color = '255,99,71'; }
  elsif ($colorname eq 'turquoise') { $color = '64,224,208'; }
  elsif ($colorname eq 'violet') { $color = '238,130,238'; }
  elsif ($colorname eq 'wheat') { $color = '245,222,179'; }
  elsif ($colorname eq 'white') { $color = '255,255,255'; }
  elsif ($colorname eq 'whitesmoke') { $color = '245,245,245'; }
  elsif ($colorname eq 'yellow') { $color = '255,255,0'; }
  elsif ($colorname eq 'yellowgreen') { $color = '154,205,50'; }
  if ($color eq '-1') { return $color; }
  return (sprintf ("#%2.2x%2.2x%2.2x", split (/,/, $color)));
}

sub printcolors {
format colors =
The following was taken from the ImageMagick web site at:
http://imagemagick.sourceforge.net/www/color.html

Here is a list of valid color strings and their corresponding values for
red, green, and blue and their hex equivalents:

Color			Red	Green	Blue	Hex
-----			---	-----	----	---
aliceblue		240	248	255	#f0f8ff
antiquewhite		250	235	215	#faebd7
aqua			0	255	255	#00ffff
aquamarine		127	255	212	#7fffd4
azure			240	255	255	#f0ffff
beige			245	245	220	#f5f5dc
bisque			255	228	196	#ffe4c4
black			0	0	0	#000000
blanchedalmond		255	235	205	#ffebcd
blue			0	0	255	#0000ff
blueviolet		138	43	226	#8a2be2
brown			165	42	42	#a52a2a
burlywood		222	184	135	#deb887
cadetblue		95	158	160	#5f9ea0
chartreuse		127	255	0	#7fff00
chocolate		210	105	30	#d2691e
coral			255	127	80	#ff7f50
cornflowerblue		100	149	237	#6495ed
cornsilk		255	248	220	#fff8dc
crimson			220	20	60	#dc143c
cyan			0	255	255	#00ffff
darkblue		0	0	139	#00008b
darkcyan		0	139	139	#008b8b
darkgoldenrod		184	134	11	#b8860b
darkgray		169	169	169	#a9a9a9
darkgreen		0	100	0	#006400
darkgrey		169	169	169	#a9a9a9
darkkhaki		189	183	107	#bdb76b
darkmagenta		139	0	139	#8b008b
darkolivegreen		85	107	47	#556b2f
darkorange		255	140	0	#ff8c00
darkorchid		153	50	204	#9932cc
darkred			139	0	0	#8b0000
darksalmon		233	150	122	#e9967a
darkseagreen		143	188	143	#8fbc8f
darkslateblue		72	61	139	#483d8b
darkslategray		47	79	79	#2f4f4f
darkslategrey		47	79	79	#2f4f4f
darkturquoise		0	206	209	#00ced1
darkviolet		148	0	211	#9400d3
deeppink		255	20	147	#ff1493
deepskyblue		0	191	255	#00bfff
dimgray			105	105	105	#696969
dimgrey			105	105	105	#696969
dodgerblue		30	144	255	#1e90ff
firebrick		178	34	34	#b22222
floralwhite		255	250	240	#fffaf0
forestgreen		34	139	34	#228b22
fractal			128	128	128	#808080
fuchsia			255	0	255	#ff00ff
gainsboro		220	220	220	#dcdcdc
ghostwhite		248	248	255	#f8f8ff
gold			255	215	0	#ffd700
goldenrod		218	165	32	#daa520
gray			126	126	126	#7e7e7e
gray0			0	0	0	#000000
gray1			3	3	3	#030303
gray10			26	26	26	#1a1a1a
gray100			255	255	255	#ffffff
gray11			28	28	28	#1c1c1c
gray12			31	31	31	#1f1f1f
gray13			33	33	33	#212121
gray14			36	36	36	#242424
gray15			38	38	38	#262626
gray16			41	41	41	#292929
gray17			43	43	43	#2b2b2b
gray18			46	46	46	#2e2e2e
gray19			48	48	48	#303030
gray2			5	5	5	#050505
gray20			51	51	51	#333333
gray21			54	54	54	#363636
gray22			56	56	56	#383838
gray23			59	59	59	#3b3b3b
gray24			61	61	61	#3d3d3d
gray25			64	64	64	#404040
gray26			66	66	66	#424242
gray27			69	69	69	#454545
gray28			71	71	71	#474747
gray29			74	74	74	#4a4a4a
gray3			8	8	8	#080808
gray30			77	77	77	#4d4d4d
gray31			79	79	79	#4f4f4f
gray32			82	82	82	#525252
gray33			84	84	84	#545454
gray34			87	87	87	#575757
gray35			89	89	89	#595959
gray36			92	92	92	#5c5c5c
gray37			94	94	94	#5e5e5e
gray38			97	97	97	#616161
gray39			99	99	99	#636363
gray4			10	10	10	#0a0a0a
gray40			102	102	102	#666666
gray41			105	105	105	#696969
gray42			107	107	107	#6b6b6b
gray43			110	110	110	#6e6e6e
gray44			112	112	112	#707070
gray45			115	115	115	#737373
gray46			117	117	117	#757575
gray47			120	120	120	#787878
gray48			122	122	122	#7a7a7a
gray49			125	125	125	#7d7d7d
gray5			13	13	13	#0d0d0d
gray50			127	127	127	#7f7f7f
gray51			130	130	130	#828282
gray52			133	133	133	#858585
gray53			135	135	135	#878787
gray54			138	138	138	#8a8a8a
gray55			140	140	140	#8c8c8c
gray56			143	143	143	#8f8f8f
gray57			145	145	145	#919191
gray58			148	148	148	#949494
gray59			150	150	150	#969696
gray6			15	15	15	#0f0f0f
gray60			153	153	153	#999999
gray61			156	156	156	#9c9c9c
gray62			158	158	158	#9e9e9e
gray63			161	161	161	#a1a1a1
gray64			163	163	163	#a3a3a3
gray65			166	166	166	#a6a6a6
gray66			168	168	168	#a8a8a8
gray67			171	171	171	#ababab
gray68			173	173	173	#adadad
gray69			176	176	176	#b0b0b0
gray7			18	18	18	#121212
gray70			179	179	179	#b3b3b3
gray71			181	181	181	#b5b5b5
gray72			184	184	184	#b8b8b8
gray73			186	186	186	#bababa
gray74			189	189	189	#bdbdbd
gray75			191	191	191	#bfbfbf
gray76			194	194	194	#c2c2c2
gray77			196	196	196	#c4c4c4
gray78			199	199	199	#c7c7c7
gray79			201	201	201	#c9c9c9
gray8			20	20	20	#141414
gray80			204	204	204	#cccccc
gray81			207	207	207	#cfcfcf
gray82			209	209	209	#d1d1d1
gray83			212	212	212	#d4d4d4
gray84			214	214	214	#d6d6d6
gray85			217	217	217	#d9d9d9
gray86			219	219	219	#dbdbdb
gray87			222	222	222	#dedede
gray88			224	224	224	#e0e0e0
gray89			227	227	227	#e3e3e3
gray9			23	23	23	#171717
gray90			229	229	229	#e5e5e5
gray91			232	232	232	#e8e8e8
gray92			235	235	235	#ebebeb
gray93			237	237	237	#ededed
gray94			240	240	240	#f0f0f0
gray95			242	242	242	#f2f2f2
gray96			245	245	245	#f5f5f5
gray97			247	247	247	#f7f7f7
gray98			250	250	250	#fafafa
gray99			252	252	252	#fcfcfc
green			0	128	0	#008000
greenyellow		173	255	47	#adff2f
grey			128	128	128	#808080
honeydew		240	255	240	#f0fff0
hotpink			255	105	180	#ff69b4
indianred		205	92	92	#cd5c5c
indigo			75	0	130	#4b0082
ivory			255	255	240	#fffff0
khaki			240	230	140	#f0e68c
lavender		230	230	250	#e6e6fa
lavenderblush		255	240	245	#fff0f5
lawngreen		124	252	0	#7cfc00
lemonchiffon		255	250	205	#fffacd
lightblue		173	216	230	#add8e6
lightcoral		240	128	128	#f08080
lightcyan		224	255	255	#e0ffff
lightgoldenrodyellow	250	250	210	#fafad2
lightgray		211	211	211	#d3d3d3
lightgreen		144	238	144	#90ee90
lightgrey		211	211	211	#d3d3d3
lightpink		255	182	193	#ffb6c1
lightsalmon		255	160	122	#ffa07a
lightseagreen		32	178	170	#20b2aa
lightskyblue		135	206	250	#87cefa
lightslategray		119	136	153	#778899
lightslategrey		119	136	153	#778899
lightsteelblue		176	196	222	#b0c4de
lightyellow		255	255	224	#ffffe0
lime			0	255	0	#00ff00
limegreen		50	205	50	#32cd32
linen			250	240	230	#faf0e6
magenta			255	0	255	#ff00ff
maroon			128	0	0	#800000
mediumaquamarine	102	205	170	#66cdaa
mediumblue		0	0	205	#0000cd
mediumorchid		186	85	211	#ba55d3
mediumpurple		147	112	219	#9370db
mediumseagreen		60	179	113	#3cb371
mediumslateblue		123	104	238	#7b68ee
mediumspringgreen	0	250	154	#00fa9a
mediumturquoise		72	209	204	#48d1cc
mediumvioletred		199	21	133	#c71585
midnightblue		25	25	112	#191970
mintcream		245	255	250	#f5fffa
mistyrose		255	228	225	#ffe4e1
moccasin		255	228	181	#ffe4b5
navajowhite		255	222	173	#ffdead
navy			0	0	128	#000080
none			0	0	0	#000000
oldlace			253	245	230	#fdf5e6
olive			128	128	0	#808000
olivedrab		107	142	35	#6b8e23
orange			255	165	0	#ffa500
orangered		255	69	0	#ff4500
orchid			218	112	214	#da70d6
palegoldenrod		238	232	170	#eee8aa
palegreen		152	251	152	#98fb98
paleturquoise		175	238	238	#afeeee
palevioletred		219	112	147	#db7093
papayawhip		255	239	213	#ffefd5
peachpuff		255	218	185	#ffdab9
peru			205	133	63	#cd853f
pink			255	192	203	#ffc0cb
plum			221	160	221	#dda0dd
powderblue		176	224	230	#b0e0e6
purple			128	0	128	#800080
red			255	0	0	#ff0000
rosybrown		188	143	143	#bc8f8f
royalblue		65	105	225	#4169e1
saddlebrown		139	69	19	#8b4513
salmon			250	128	114	#fa8072
sandybrown		244	164	96	#f4a460
seagreen		46	139	87	#2e8b57
seashell		255	245	238	#fff5ee
sienna			160	82	45	#a0522d
silver			192	192	192	#c0c0c0
skyblue			135	206	235	#87ceeb
slateblue		106	90	205	#6a5acd
slategray		112	128	144	#708090
slategrey		112	128	144	#708090
snow			255	250	250	#fffafa
springgreen		0	255	127	#00ff7f
steelblue		70	130	180	#4682b4
tan			210	180	140	#d2b48c
teal			0	128	128	#008080
thistle			216	191	216	#d8bfd8
tomato			255	99	71	#ff6347
turquoise		64	224	208	#40e0d0
violet			238	130	238	#ee82ee
wheat			245	222	179	#f5deb3
white			255	255	255	#ffffff
whitesmoke		245	245	245	#f5f5f5
yellow			255	255	0	#ffff00
yellowgreen		154	205	50	#9acd32

.
$~ = "colors";
write;
exit(-2);
}

sub printfonts {
  use Image::Magick;
  my $fontimage = new Image::Magick;
  my @fontlist = $fontimage->QueryFont;
  print "Here is a list of valid fonts accessible to slcview.pl:\n\n";
  print join ("\n", @fontlist), "\n";
  exit(-2);
}

sub printgnu {
format gnu =
		    GNU GENERAL PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. This License applies to any program or other work which contains
a notice placed by the copyright holder saying it may be distributed
under the terms of this General Public License.  The "Program", below,
refers to any such program or work, and a "work based on the Program"
means either the Program or any derivative work under copyright law:
that is to say, a work containing the Program or a portion of it,
either verbatim or with modifications and/or translated into another
language.  (Hereinafter, translation is included without limitation in
the term "modification".)  Each licensee is addressed as "you".

Activities other than copying, distribution and modification are not
covered by this License; they are outside its scope.  The act of
running the Program is not restricted, and the output from the Program
is covered only if its contents constitute a work based on the
Program (independent of having been made by running the Program).
Whether that is true depends on what the Program does.

  1. You may copy and distribute verbatim copies of the Program's
source code as you receive it, in any medium, provided that you
conspicuously and appropriately publish on each copy an appropriate
copyright notice and disclaimer of warranty; keep intact all the
notices that refer to this License and to the absence of any warranty;
and give any other recipients of the Program a copy of this License
along with the Program.

You may charge a fee for the physical act of transferring a copy, and
you may at your option offer warranty protection in exchange for a fee.

  2. You may modify your copy or copies of the Program or any portion
of it, thus forming a work based on the Program, and copy and
distribute such modifications or work under the terms of Section 1
above, provided that you also meet all of these conditions:

    a) You must cause the modified files to carry prominent notices
    stating that you changed the files and the date of any change.

    b) You must cause any work that you distribute or publish, that in
    whole or in part contains or is derived from the Program or any
    part thereof, to be licensed as a whole at no charge to all third
    parties under the terms of this License.

    c) If the modified program normally reads commands interactively
    when run, you must cause it, when started running for such
    interactive use in the most ordinary way, to print or display an
    announcement including an appropriate copyright notice and a
    notice that there is no warranty (or else, saying that you provide
    a warranty) and that users may redistribute the program under
    these conditions, and telling the user how to view a copy of this
    License.  (Exception: if the Program itself is interactive but
    does not normally print such an announcement, your work based on
    the Program is not required to print an announcement.)

These requirements apply to the modified work as a whole.  If
identifiable sections of that work are not derived from the Program,
and can be reasonably considered independent and separate works in
themselves, then this License, and its terms, do not apply to those
sections when you distribute them as separate works.  But when you
distribute the same sections as part of a whole which is a work based
on the Program, the distribution of the whole must be on the terms of
this License, whose permissions for other licensees extend to the
entire whole, and thus to each and every part regardless of who wrote it.

Thus, it is not the intent of this section to claim rights or contest
your rights to work written entirely by you; rather, the intent is to
exercise the right to control the distribution of derivative or
collective works based on the Program.

In addition, mere aggregation of another work not based on the Program
with the Program (or with a work based on the Program) on a volume of
a storage or distribution medium does not bring the other work under
the scope of this License.

  3. You may copy and distribute the Program (or a work based on it,
under Section 2) in object code or executable form under the terms of
Sections 1 and 2 above provided that you also do one of the following:

    a) Accompany it with the complete corresponding machine-readable
    source code, which must be distributed under the terms of Sections
    1 and 2 above on a medium customarily used for software interchange; or,

    b) Accompany it with a written offer, valid for at least three
    years, to give any third party, for a charge no more than your
    cost of physically performing source distribution, a complete
    machine-readable copy of the corresponding source code, to be
    distributed under the terms of Sections 1 and 2 above on a medium
    customarily used for software interchange; or,

    c) Accompany it with the information you received as to the offer
    to distribute corresponding source code.  (This alternative is
    allowed only for noncommercial distribution and only if you
    received the program in object code or executable form with such
    an offer, in accord with Subsection b above.)

The source code for a work means the preferred form of the work for
making modifications to it.  For an executable work, complete source
code means all the source code for all modules it contains, plus any
associated interface definition files, plus the scripts used to
control compilation and installation of the executable.  However, as a
special exception, the source code distributed need not include
anything that is normally distributed (in either source or binary
form) with the major components (compiler, kernel, and so on) of the
operating system on which the executable runs, unless that component
itself accompanies the executable.

If distribution of executable or object code is made by offering
access to copy from a designated place, then offering equivalent
access to copy the source code from the same place counts as
distribution of the source code, even though third parties are not
compelled to copy the source along with the object code.

  4. You may not copy, modify, sublicense, or distribute the Program
except as expressly provided under this License.  Any attempt
otherwise to copy, modify, sublicense or distribute the Program is
void, and will automatically terminate your rights under this License.
However, parties who have received copies, or rights, from you under
this License will not have their licenses terminated so long as such
parties remain in full compliance.

  5. You are not required to accept this License, since you have not
signed it.  However, nothing else grants you permission to modify or
distribute the Program or its derivative works.  These actions are
prohibited by law if you do not accept this License.  Therefore, by
modifying or distributing the Program (or any work based on the
Program), you indicate your acceptance of this License to do so, and
all its terms and conditions for copying, distributing or modifying
the Program or works based on it.

  6. Each time you redistribute the Program (or any work based on the
Program), the recipient automatically receives a license from the
original licensor to copy, distribute or modify the Program subject to
these terms and conditions.  You may not impose any further
restrictions on the recipients' exercise of the rights granted herein.
You are not responsible for enforcing compliance by third parties to
this License.

  7. If, as a consequence of a court judgment or allegation of patent
infringement or for any other reason (not limited to patent issues),
conditions are imposed on you (whether by court order, agreement or
otherwise) that contradict the conditions of this License, they do not
excuse you from the conditions of this License.  If you cannot
distribute so as to satisfy simultaneously your obligations under this
License and any other pertinent obligations, then as a consequence you
may not distribute the Program at all.  For example, if a patent
license would not permit royalty-free redistribution of the Program by
all those who receive copies directly or indirectly through you, then
the only way you could satisfy both it and this License would be to
refrain entirely from distribution of the Program.

If any portion of this section is held invalid or unenforceable under
any particular circumstance, the balance of the section is intended to
apply and the section as a whole is intended to apply in other
circumstances.

It is not the purpose of this section to induce you to infringe any
patents or other property right claims or to contest validity of any
such claims; this section has the sole purpose of protecting the
integrity of the free software distribution system, which is
implemented by public license practices.  Many people have made
generous contributions to the wide range of software distributed
through that system in reliance on consistent application of that
system; it is up to the author/donor to decide if he or she is willing
to distribute software through any other system and a licensee cannot
impose that choice.

This section is intended to make thoroughly clear what is believed to
be a consequence of the rest of this License.

  8. If the distribution and/or use of the Program is restricted in
certain countries either by patents or by copyrighted interfaces, the
original copyright holder who places the Program under this License
may add an explicit geographical distribution limitation excluding
those countries, so that distribution is permitted only in or among
countries not thus excluded.  In such case, this License incorporates
the limitation as if written in the body of this License.

  9. The Free Software Foundation may publish revised and/or new versions
of the General Public License from time to time.  Such new versions will
be similar in spirit to the present version, but may differ in detail to
address new problems or concerns.

Each version is given a distinguishing version number.  If the Program
specifies a version number of this License which applies to it and "any
later version", you have the option of following the terms and conditions
either of that version or of any later version published by the Free
Software Foundation.  If the Program does not specify a version number of
this License, you may choose any version ever published by the Free Software
Foundation.

  10. If you wish to incorporate parts of the Program into other free
programs whose distribution conditions are different, write to the author
to ask for permission.  For software which is copyrighted by the Free
Software Foundation, write to the Free Software Foundation; we sometimes
make exceptions for this.  Our decision will be guided by the two goals
of preserving the free status of all derivatives of our free software and
of promoting the sharing and reuse of software generally.

			    NO WARRANTY

  11. BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS
TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE
PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
REPAIR OR CORRECTION.

  12. IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES,
INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING
OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED
TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY
YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER
PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGES.

		     END OF TERMS AND CONDITIONS

.
$~ = "gnu";
write;
exit(-2);
}
