#!/usr/bin/perl -w

use strict;

die "$0: Must be run from Xcode" unless $ENV{"BUILT_PRODUCTS_DIR"};

my $REV = `svn info | grep "^Revision:"`;
my $INFO = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{WRAPPER_NAME}/Contents/Info.plist";

my $version = $REV;
$version =~ s/^Revision: (\d+)\n/$1/;
die "$0: No Subversion revision found" unless $version;
my $prevversion = $version - 1;

open(FH, "$INFO") or die "$0: $INFO: $!";
my $info = join("", <FH>);
close(FH);

$info =~ s/([\t ]+<key>CFBundleVersion<\/key>\n[\t ]+<string>).*?(<\/string>)/$1$version$2/;

open(FH, ">$INFO") or die "$0: $INFO: $!";
print FH $info;
close(FH);

system("rm -rf '$ENV{BUILT_PRODUCTS_DIR}/$ENV{EXECUTABLE_NAME} build $prevversion.$ENV{WRAPPER_EXTENSION}'");
system("ln -sf '$ENV{BUILT_PRODUCTS_DIR}/$ENV{WRAPPER_NAME}' '$ENV{BUILD_DIR}/$ENV{EXECUTABLE_NAME} build $version.$ENV{WRAPPER_EXTENSION}'");
