#!/usr/bin/perl -w

use strict;

die "$0: Must be run from Xcode" unless $ENV{"BUILT_PRODUCTS_DIR"};

$ENV{"PATH"} = "/opt/local/bin:/usr/local/bin:/usr/bin";

my $REV = `svn info | grep "^Revision:"`;

my $version = $REV;
$version =~ s/^Revision: (\d+)\n/$1/;
die "$0: No Subversion revision found" unless $version;

my @files = @ARGV;

if(@files == 0) {
	push(@files, "$ENV{BUILT_PRODUCTS_DIR}/$ENV{INFOPLIST_PATH}");
}

foreach my $file (@files) {
	open(FH, "$file") or die "$0: $file: $!";
	my $content = join("", <FH>);
	close(FH);

	$content =~ s/([\t ]+<key>CFBundleVersion<\/key>\n[\t ]+<string>).*?(<\/string>)/$1$version$2/;
	$content =~ s/\$\(?SVN_REVISION\)?/$version/g;
	
	open(FH, ">$file") or die "$0: $file: $!";
	print FH $content;
	close(FH);
}

