#!/usr/local/bin/perl
use strict;
use warnings;
use POSIX;

# set up in sub getSSfilepath:
my $profdir;		# firefox profile dir
my $sessfn;		# the selected session file to process (full path)
# set up in sub read_sessionfile:
my $sesstext;		# the session file as string
# set up in sub getWMstat:
my $vDskSzX; my$vDskSzY;	# Virtual desktop size
my $vScrSzX; my $vScrSzY;	# Virtual screen (viewport) size
my $curScrX; my $curScrY;	# current screen 
my $nDsks;			# Number of virtual desktops
# window session parameters, set up in sub getSessStats:
my @sessBusy;
my @sessWidth;
my @sessHeight;
my @sessScreenX;
my @sessScreenY;
my @sessSizeMode;
my $nrWindows;
# file modification flag, set up in sub processSessStats
my $dowriteback = 1;

my $v = 1; 		# verbosity

# Subroutines:
# getWMstat;
# getSSdir
# getSSfilepath;
# read_sessionfile;
# getSessStats;
# sub processSessStats
# sub write_sessionfile

sub getWMstat
{
  # first we need to know some things about the system currently running:
  my $info = qx{xprop -display \$DISPLAY -root};    # call xprop
  die "$0: xprop command not available!\n" if $?;
#   print $info;
  ($vDskSzX, $vDskSzY) = $info =~ /^_NET_DESKTOP_GEOMETRY\(CARDINAL\) = (\d+), (\d+)/m;
  ($vScrSzX, $vScrSzY) = $info =~ /^_NET_WORKAREA\(CARDINAL\) =.+?(\d+), (\d+)$/m;
  ($nDsks) = $info =~ /^_NET_NUMBER_OF_DESKTOPS\(CARDINAL\) = (\d+)/m;
  ($curScrX, $curScrY) = $info =~ /^_WIN_AREA\(CARDINAL\) = (\d+), (\d+)$/m;
  # current screen 
  
  if ($v) {
    print "Virtual desktop size  X = $vDskSzX  Y = $vDskSzY\n";
    print "Virtual screen (viewport) size  X = $vScrSzX  Y = $vScrSzY\n";
    print "Number of virtual desktops  = $nDsks\n";
    print "Current desktop screen  X = $curScrX  Y = $curScrY\n";
} }

sub getSSdir
{
  my $ffdir = $ENV{"HOME"} . '/.mozilla/firefox';
  if ( -e $ffdir ) {
    opendir (DIR, $ffdir) or die $!;
    while ( my $pfdir = readdir(DIR)) {
      if ($pfdir =~ /\S+\.default$/) {
	$profdir = $ffdir . '/' . $pfdir;
        $sessfn = $profdir . '/sessionstore.js';
        if ( -e $sessfn ) {
	  if ($v) { print "Found session file: $sessfn\n"; }
	  closedir (DIR);
	  return 0;
	}
	last;
  } } }
  closedir (DIR);
  return 1;
}

sub getSSfilepath
{
  return 0 if !getSSdir();
  # sessionstore file not found. Use a backup if present.
  my $pbd = $profdir . '/sessionstore-backups';
  die "No backup dir!\n" if (not -e $pbd);
  $pbd .= '/';
  my @rfs = ( $pbd . 'recovery.js', $pbd . 'recovery.bak', $pbd . 'previous.js');
  # get the update files too
  my @tfa = ();
  opendir (DIR, $pbd) or die $!;
  while ( my $fn = readdir(DIR)) {
    push (@tfa, $pbd . $fn) if ($fn =~ /^upgrade\.js-.*/);
  }
  closedir (DIR);
  push @rfs, sort @tfa;
  foreach (@rfs) {
    if ( -e ) {
      qx( cp $_ $sessfn );
      if ($v) { print "No session file found, Recovery file $_ copied to $sessfn.\n"; }
      return 0;
  } }
  return 1;
}

sub read_sessionfile
{
  local $/ = undef;
  open FILE, $sessfn or die "Couldn't open file: $!";
  $sesstext = <FILE>;
  close FILE;
}

sub getSessStats
{
  @sessWidth  = $sesstext =~ /\"width\":([-\d]+),\"height\":[-\d]+,\"screenX\":[-\d]+,\"screenY\":[-\d]+,\"sizemode\":\"\w+\"/gs;
  @sessHeight  = $sesstext =~ /\"width\":[-\d]+,\"height\":([-\d]+),\"screenX\":[-\d]+,\"screenY\":[-\d]+,\"sizemode\":\"\w+\"/gs;
  @sessScreenX  = $sesstext =~ /\"width\":[-\d]+,\"height\":[-\d]+,\"screenX\":([-\d]+),\"screenY\":[-\d]+,\"sizemode\":\"\w+\"/gs;
  @sessScreenY  = $sesstext =~ /\"width\":[-\d]+,\"height\":[-\d]+,\"screenX\":[-\d]+,\"screenY\":([-\d]+),\"sizemode\":\"\w+\"/gs;
  @sessSizeMode  = $sesstext =~ /\"width\":[-\d]+,\"height\":[-\d]+,\"screenX\":[-\d]+,\"screenY\":[-\d]+,\"sizemode\":\"(\w+)\"/gs;

  $nrWindows = scalar @sessWidth;
  if ($v) {
    for (my $n=0; $n < $nrWindows; ++$n) {
#       print "Window $n   width: " . $sessWidth[$n] . '  height: ' . $sessHeight[$n] . 
# 	  '   screenX: ' . $sessScreenX[$n] . '  screenY: ' . $sessScreenY[$n] . '   sizemode: ' . $sessSizeMode[$n] , "\n";
      print "Window $n   width: $sessWidth[$n]  height: $sessHeight[$n]   screenX: $sessScreenX[$n]  screenY: $sessScreenY[$n]   sizemode: $sessSizeMode[$n]\n";
} } }


sub sessWindowsReorder
{
  # place the windows just like a card stack to be reordered manually :)
  $sesstext =~ s{\"width\":([-\d]+),\"height\":([-\d]+),\"screenX\":([-\d]+),\"screenY\":([-\d]+),\"sizemode\":\"(\w+)\"}
	        {\"width\":$1,\"height\":$2,\"screenX\":0,\"screenY\":0,\"sizemode\":\"$5"}sg;
  if ($v) { print "Windows have been reordered.\n"; };
}


sub processSessStats
{
  # Explanation: The screen coordinates in the sessionstore.js get are relative, not absolute.
  # Determine their minmax range, and try to calculate the original absolute positions.
  my $xMin = $vDskSzX;
  my $xMax = 0;
  my $yMin = $vDskSzY;
  my $yMax = 0;
  for (my $n = 0; $n < $nrWindows; ++$n) {
    $xMin = $sessScreenX[$n] if $sessScreenX[$n] < $xMin;
    $xMax = $sessScreenX[$n] if $sessScreenX[$n] > $xMax;
    $yMin = $sessScreenY[$n] if $sessScreenY[$n] < $yMin;
    $yMax = $sessScreenY[$n] if $sessScreenY[$n] > $yMax;
  }
  my $FxMin = floor( $xMin / $vScrSzX);
  my $FxMax = ceil( $xMax / $vScrSzX);
  my $FyMin = floor( $yMin / $vScrSzY);
  my $FyMax = ceil( $yMax / $vScrSzY);
  my $spanX = abs($FxMin) + abs($FxMax);
  my $spanY = abs($FyMin) + abs($FyMax);
  my $dsktspanX = $vDskSzX / $vScrSzX;
  my $dsktspanY = $vDskSzY / $vScrSzY;
  my $offsX = -$FxMin;
  my $offsY = -$FyMin;
  
  if ($v) {
    print "Range of windows spread over desktop:  xMin: $xMin  xMax: $xMax  yMin: $yMin  yMax: $yMax\n";
    print "FxMin: $FxMin   FxMax: $FxMax   FyMin: $FyMin   FyMax: $FyMax   X span: $spanX     Y span: $spanY\n";
  }
  
  if ($spanX > $dsktspanX) {
    # windows moved offscreen by user (probably intentional) ?
    if ($spanX > $dsktspanX + 1) {
      sessWindowsReorder;
      return;
    }
    for (my $n = 0; $n < $nrWindows; ++$n) {
      if ($sessScreenX[$n] + $sessWidth[$n] < ($FxMin + 1) * $vScrSzX) {
	sessWindowsReorder;
	return;
    } }
    ++$offsX;
  }
  if ($spanY > $dsktspanY) {
    if ($spanY > $dsktspanY + 1) {
      sessWindowsReorder;
      return;
    }
    for (my $n = 0; $n < $nrWindows; ++$n) {
      if ($sessScreenY[$n] + $sessHeight[$n] < ($FyMin + 1) * $vScrSzY) {
	sessWindowsReorder;
	return;
    } }
    ++$offsY;
  }

  $offsX -= $curScrX;		# convert back to rel coordinates...
  $offsY -= $curScrY;
  if ($offsX || $offsY) {
    # replace the wrong screenX/Y values in sessionstore.js
    for (my $n = 0; $n < $nrWindows; ++$n ) {
      my $oldX = $sessScreenX[$n];
      my $newX = $oldX + $offsX * $vScrSzX;
      my $oldY = $sessScreenY[$n];
      my $newY = $oldY + $offsY * $vScrSzY;
      $sesstext =~ s{\"width\":([-\d]+),\"height\":([-\d]+),\"screenX\":($oldX),\"screenY\":($oldY),\"sizemode\":\"(\w+)\"}
		    {\"width\":$1,\"height\":$2,\"screenX\":$newX,\"screenY\":$newY,\"sizemode\":\"$5"};
      if ($v) { print "Window $n: screenX old: $oldX  new: $newX    screenY old: $oldY  new: $newY\n"; };
    }
    if ($v) { print "Windows have been shifted by offsets X $offsX and Y $offsY screens.\n"; };
  } else {
    $dowriteback = 0;
    if ($v) { print "No correction needed.\n"; };
} }


sub write_sessionfile
{
  open my $file, '>', $sessfn or die $!;
  print $file $sesstext or die $!;
  close $file or die $!;
  if ($v) { print "Session file successfully written.\n"; }
}

# main section
my $ps = `ps x`;
if (scalar @ARGV && $ps =~ /firefox/s) { die "Firefox is already running.\n" }
getWMstat;
if (not getSSfilepath()) {
  read_sessionfile;
  getSessStats;
  processSessStats;
  if ($dowriteback && scalar @ARGV >= 1 && $ARGV[0] eq '-w') { write_sessionfile; }
}
if (scalar @ARGV >= 1 && $ARGV[0] eq '-w') { qx(firefox) }

