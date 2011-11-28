#!/usr/bin/perl -w

use strict;

die "$0: Must be run from Xcode" unless $ENV{"BUILT_PRODUCTS_DIR"};

$ENV{"PATH"} = "/opt/local/bin:/usr/local/bin:/usr/bin";

my $REV = `svn info | grep "^Revision:"`;

my $version = $REV;
$version =~ s/^Revision: (\d+)\n/$1/;
die "$0: No Subversion revision found" unless $version;

my $INFO = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{WRAPPER_NAME}/Contents/Info.plist";

open(FH, "$INFO") or die "$0: $INFO: $!";
my $info = join("", <FH>);
close(FH);

$info =~ s/([\t ]+<key>CFBundleVersion<\/key>\n[\t ]+<string>).*?(<\/string>)/$1$version$2/;

open(FH, ">$INFO") or die "$0: $INFO: $!";
print FH $info;
close(FH);
