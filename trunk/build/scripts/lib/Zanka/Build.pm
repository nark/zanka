package Zanka::Build;

# $Id: build.pl 5647 2008-08-06 10:07:35Z morris $

#  Copyright (c) 2008-2009 Axel Andersson
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

use Config::INI::Simple ();
use File::Basename ();
use RTF::TEXT::Converter ();
use POSIX ();

my $ERROR_MATCH_PATTERN     = "(error:|undefined reference|pbxcp:)";
my $WARNING_MATCH_PATTERN   = "(warning:)";



sub new {
	my($name, $args) = @_;
	
	my $self = {};
	bless($self);
	
	$self->{"path"} = $args->{"path"};
	$self->{"style"} = $args->{"style"};
	
	my $conf = Config::INI::Simple->new();
	
	$conf->read($self->fullPathForPath("build.conf")) or die "Could not read build.conf: $!";
	
	$self->{"config"} = $conf;
	$self->{"config"}->{"current"} = $self->{"config"}->{"default"};
	
	if($self->{"style"}) {
		foreach (keys %{$self->{"config"}->{$self->{"style"}}}) {
			$self->{"config"}->{"current"}->{$_} = $self->{"config"}->{$self->{"style"}}->{$_};
		}
	}
	
	return $self;
}



sub fullPathForPath {
	my($self, $path) = @_;

	return $self->{"path"} . "/$path";
}



sub projects {
	my($self) = @_;

	if(!$self->{"projects"}) {
		my @projects;
				
		if($self->{"config"}->{"default"}->{"projects"}) {
			@projects = split(/\s+/, $self->{"config"}->{"default"}->{"projects"});
		}
		else {
			opendir(DH, $self->fullPathForPath("projects")) or die "Could not read projects/: $!";
			@projects = grep { !/^\./} readdir(DH);
			closedir(DH);
		}
		
		my $projects_ignore = $self->{"config"}->{"current"}->{"projects_ignore"};
		
		if($projects_ignore) {
			$projects_ignore =~ s/ /\|/g;
			
			@projects = grep { !/($projects_ignore)/ } @projects;
		}

		$self->{"projects"} = \@projects;
	}

	return $self->{"projects"};
}



sub buildProjects {
	my($self, $projects) = @_;

	mkdir($self->{"config"}->{"current"}->{"work_path"}); 
	
	my $build;
	my $revisionpath = $self->{"config"}->{"current"}->{"work_path"} . "/revision";
	my $previousrevision;
	my $svninfo = $self->subversionInfoAtURL($self->{"config"}->{"current"}->{"svn_url"});
	my $revision = $svninfo->{"Last Changed Rev"};
		
	if(open(FH, $revisionpath)) {
		$previousrevision = <FH>;
			
		chomp($previousrevision);
			
		close(FH);
	}
	
	if($self->{"config"}->{"current"}->{"build_only_if_changed"}) {
		if($previousrevision && $revision eq $previousrevision) {
			print "Ignoring builds of projects because they haven't changed\n";

			return;
		}
	}

	my $lockpath = $self->{"config"}->{"current"}->{"work_path"} . "/lock";

	if(-f $lockpath) {
		print "Build is already ongoing, according to $lockpath\n";

		return;
	}
	
	my @projects;
	
	if(@{$projects}) {
		@projects = @{$projects};
	} else {
		@projects = @{$self->projects};
	}

	open(FH, ">$lockpath") and close(FH) or die "$!";

	foreach my $project (@projects) {
		if($self->canBuildProject($project)) {
			$self->buildProject($project);
		} else {
			print "Ignoring build of $project because of dependency restraints\n";
		}
	}
	
	if($revision) {
		if(open(FH, ">$revisionpath")) {
			print FH "$revision\n";
			close(FH);
		}
	}

	unlink($lockpath) or die "$!";
}



sub buildProject {
	my($self, $project) = @_;
	
	my $config = $self->configForProject($project);
	my $date = POSIX::strftime("%Y-%m-%d", localtime());
	
	$config->{"distball"} = $config->{"distname"};
	$config->{"distball"} =~ s/%X/$date/i;
	
	$self->buildProjectWithConfig($project, $config);
}



sub buildLatestTagOfProject {
	my($self, $project) = @_;
	
	my @versions = $self->versionHistoryForProject($project, 1);

	return unless @versions;

	$version = $versions[0]->{"version"};
	
	my $config = $self->configForProject($project);
	
	$config->{"svn_full_url"} = "$config->{svn_url}/tags/$config->{svn_path}-$version/$config->{svn_path}";
	$config->{"distball"} = lc($config->{"distname"});
	$config->{"distball"} =~ s/%X/$version/i;
	
	$self->buildProjectWithConfig($project, $config);
}



sub buildProjectWithConfig {
	my($self, $project, $config) = @_;
	
	my $variables = "";
	
	foreach (sort keys %$config) {
		$variables .= uc($_) . "=\"$config->{$_}\" ";
	}
	
	my $starttime = time();
	
	my $workpath = $config->{"work_path"} . "/$project";
	my $makepath = $self->fullPathForPath("scripts/build.mk");

	system("mkdir -p '$workpath'");
	system("cp '$makepath' '$workpath/build.mk'");

	open(MAKE, "$config->{make} -C '$workpath' -f 'build.mk' $variables 2>&1|");

	my $log;
	my $errorslog;
	my $warningslog;
	my $testslog;
	
	my $errors = 0;
	my $warnings = 0;
	my $failedtests = 0;
	
	my $testing = 0;

	while(<MAKE>) {
		if(/$ERROR_MATCH_PATTERN/ && !/$config->{"error_ignore"}/) {
			$errors++;
			$errorslog .= $_;
		}
		elsif(/$WARNING_MATCH_PATTERN/ && !/$config->{"warning_ignore"}/) {
			$warnings++;
			$warningslog .= $_;
		}
		elsif(/^Tests started/) {
			$testing = 1;
		}
		
		$log .= $_;
		$testslog .= $_ if $testing;
		
		if(/(\d+?) tests? passed .+? (\d+?) failed/) {
			$failedtests = $2;
			$testing = 0;
		}
		
		print;
	}
	
	close(MAKE);
	
	my $success = ($? == 0);
	my $time = time() - $starttime;
	my($host, $os, $arch) = $self->currentHostOSAndArch();
	
	open(REPORT, ">" . $self->fullPathForPath("reports/$project.log")) or die "$project.log: $!";
	
	print REPORT "Project:       $project\n";
	print REPORT "Branch:        $config->{svn_branch}\n";
	print REPORT "Build Time:    " . $self->intervalStringForTime($time) . "\n\n";
	
	print REPORT "Host:          $host\n";
	print REPORT "OS:            $os\n";
	print REPORT "Arch:          $arch\n\n";
	
	if($errors > 0) {
		print REPORT "Errors ($errors):\n";
		print REPORT $errorslog;
		print REPORT "\n";
	}
	
	if($warnings > 0) {
		print REPORT "Warnings ($warnings):\n";
		print REPORT $warningslog;
		print REPORT "\n";
	}
	
	if($testslog) {
		print REPORT "Tests ($failedtests failed):\n";
		print REPORT $testslog;
		print REPORT "\n";
	}
	
	print REPORT "Log:\n";
	print REPORT $log if $log;
	
	close(REPORT);

	if($config->{"mailsuccess"} || !$success ||
	   ($errors > 0 && $config->{"mailerrors"}) ||
	   ($warnings > 0 && $config->{"mailwarnings"}) ||
	   ($failedtests > 0 && $config->{"mailfailedtests"})) {
		my $subject;
		
		if($self->{"style"} eq "nightly") {
			$subject = "Nightly build";
		}
		elsif($self->{"style"} eq "rolling") {
			$subject = "Rolling build";
		}
		elsif($self->{"style"} eq "release") {
			$subject = "Release build";
		}
		else {
			$subject = "Build";
		}
		
		$subject .= " of $project " . ($success ? "succeeded" : "failed") . " on $host/$os/$arch";
		
		if($warnings > 0 || $errors > 0 || $failedtests > 0) {
			my $string;
			
			if($errors > 0) {
				$string .= "$errors " . (($errors == 1) ? "error" : "errors");
			}
			
			if($warnings > 0) {
				$string .= ", " if $string;
				$string .= "$warnings " . (($warnings == 1) ? "warning" : "warnings");
			}
			
			if($failedtests > 0) {
				$string .= ", " if $string;
				$string .= "$failedtests " . (($failedtests == 1) ? "test failed" : "tests failed");
			}
			
			$subject .= " ($string)";
		}
		
		open(MAIL, "|mail -s '$subject' '$config->{mail}'");
		open(REPORT, $self->fullPathForPath("reports/$project.log")) or die "$project.log: $!";
		
		while(<REPORT>) {
			print MAIL $_;
		}
		
		close(REPORT);
		close(MAIL);
	}
}



sub tagProject {
	my($self, $project, $version) = @_;

	my $config = $self->configForProject($project);

	`$config->{svn} mkdir -m "Tag" "$config->{svn_url}/tags/$project-$version/"`;
	`$config->{svn} copy -m "Tag" "$config->{svn_url}/trunk/$project" "$config->{svn_url}/tags/$project-$version/$project"`;

	if($config->{"xcodebuild"}) {
		`$config->{svn} copy -m "Tag" "$config->{svn_url}/trunk/WiredAdditions" "$config->{svn_url}/tags/$project-$version/WiredAdditions"`;
	}

	`$config->{svn} copy -m "Tag" "$config->{svn_url}/trunk/libwired" "$config->{svn_url}/tags/$project-$version/libwired"`;

	if($project eq "WiredServer") {
		`$config->{svn} copy -m "Tag" "$config->{svn_url}/trunk/wired" "$config->{svn_url}/tags/$project-$version/wired"`;
	}
}



sub canBuildProject {
	my($self, $project) = @_;

	my $config = $self->configForProject($project);

	if($config->{"xcodebuild"}) {
		return 0 unless -x "/usr/bin/xcodebuild";
		
		if($config->{"xcode_version"}) {
			my $version = `/usr/bin/xcodebuild -version`;

			return 0 unless $version =~ /Xcode ([\d\.]+)/;

			$version =~ s/Xcode ([\d\.]+).*/$1/gs;

			return 0 unless $version && $version =~ /\d/;
			return ($self->compareVersionNumbers($version, $config->{"xcode_version"}) >= 0);
		}
	}

	return 1;
}



sub configForProject {
	my($self, $project) = @_;
	
	if(!$self->{"projectconfigs"}->{$project}) {
		my $conf = Config::INI::Simple->new();
		
		$conf->read($self->fullPathForPath("/projects/$project")) or die "Could not read projects/$project: $!";
		
		my $config = {%{$self->{"config"}->{"current"}}};
		
		$config->{"project"} = $project;

		foreach (keys %{$conf->{"default"}}) {
			$config->{$_} = $conf->{"default"}->{$_};
		}

		if($config->{"svn_branch"} eq "trunk") {
			$config->{"svn_full_url"} = "$config->{svn_url}/$config->{svn_branch}/$config->{svn_path}";
		} else {
			$config->{"svn_full_url"} = "$config->{svn_url}/branches/$config->{svn_branch}/$config->{svn_path}";
		}

		$self->{"projectconfigs"}->{$project} = $config;
	}

	return $self->{"projectconfigs"}->{$project};
}



sub versionHistoryForProject {
	my($self, $project, $checktags) = @_;

	my $config = $self->configForProject($project);

	return unless $config->{"readme"};

	my $readme = `$config->{"svn"} cat $config->{"svn_full_url"}/$config->{"readme"}`;
	my $text;

	if($config->{"readme"} =~ /\.rtf$/) {
		my $converter = RTF::TEXT::Converter->new(output => \$text);
		$converter->parse_string($readme);
	} else {
		$text = $readme;	
	}

	my @lines = split(/\n/, $text);
	my @versions;
	my $history;

	foreach my $line (@lines) {
		if($line =~ /^(\d\.[\d\.]+)$/) {
			my $info = `$config->{"svn"} info $config->{"svn_url"}/tags/$config->{"svn_path"}-$1 2>/dev/null` if $checktags;

			if(!$checktags || $info) {
				my $version = {version => $1};
				push(@versions, $version);
				$history = 1;
			}
		}
		elsif($line =~ /^- / && $history) {
			$line =~ s/^- //;

			push(@{$versions[-1]->{"history"}}, $line);
		}
		elsif($line !~ /^- / && $history) {
			$history = 0;
		}
	}

	return @versions;
}



sub formattedVersionHistoryWithFormat {
	my($self, $versions, $format) = @_;

	my $history = "";

	if($format eq "www") {
		$history .= <<EOF;
<? include appheader ?>

<div class="content">
<span class="largetitle">What's New?</span>

<br />
<br />

EOF
	}

	my $i = 0;

	foreach my $version (@{$versions}) {
		if($format eq "www") {
			$history .= "$version->{version}\n";
		}
		elsif($format eq "appcast") {
			$history .= "$version->{version}\n";
		}
		elsif($format eq "macupdate") {
			$history .= "Version $version->{version}\n";
		}
		elsif($format eq "forum") {
			$history .= "[h]Version $version->{version}\[/h]\n";
		}

		if($format eq "forum") {
			$history .= "[list]\n"
		} else {
			$history .= "<ul>\n";
		}

		foreach my $item (@{$version->{"history"}}) {
			if($format eq "forum") {
				$history .= "[*]$item\[/*]\n";
			} else {
				$history .= "<li>$item</li>\n";
			}
		}

		if($format eq "forum") {
			$history .= "[/list]\n"
		} else {
			$history .= "</ul>\n";
		}

		if($format eq "appcast" || $format eq "macupdate" || $format eq "forum") {
			last;
		}

		if($i != @{$versions} - 1) {
			$history .= "\n<br />\n\n";
		}

		$i++;
	}

	if($format eq "www") {
		$history .= <<EOF;
</div>

<? include menu ?>
<? include footer ?>
EOF
	}

	return $history;
}



sub appcastForProject {
	my($self, $project, $style, $file) = @_;

	my $config = $self->configForProject($project);

	my $version;
	my $description;
	my $svninfo;
	my $distpath;
	my $disturl;

	if($style eq "release") {
		my @versions = $self->versionHistoryForProject($project, 1);

		return unless @versions;

		$distpath = "$config->{website_path}/dist/$config->{releaseball}";
		$disturl = "$config->{website_url}/dist/$config->{releaseball}";

		my $realdistpath = readlink($distpath);

		foreach my $eachversion (@versions) {
			if($realdistpath =~ /$eachversion->{version}/) {
				$version = $eachversion;

				last;
			}
		}
		
		return unless $version;

		@versions = ($version);

		$description = $self->formattedVersionHistoryWithFormat(\@versions, "appcast");
		$svninfo = $self->latestSubversionInfoAtURL($config, "$config->{svn_url}/tags/$config->{svn_path}-$version->{version}/$config->{svn_path}");
	} else {
		my @versions = $self->versionHistoryForProject($project, 0);

		return unless @versions;

		my $nightlypath = "$config->{website_path}/nightly";
		my $distpattern = $config->{"distname"};
		$distpattern =~ s/%X/%Y-%m-%d/;

		for(my $i = 0; $i < 7; $i++) {
			my $distname = Date::Format::time2str($distpattern, time() - ($i * 86400));
			$distpath = `find $nightlypath -name "$distname" 2>/dev/null`;
			chomp($distpath);
			last if $distpath && -f $distpath;
		}

		if(!$distpath) {
			warn "Could not create appcast for $project: $distpattern not found\n";

			return;
		}

		my $nightlyname = $distpath;
		$nightlyname =~ s/$nightlypath\///g;
		$disturl = $config->{"website_url"} . "/nightly/$nightlyname";

		my $svndate = Date::Format::time2str("%Y-%m-%d %H:%M:%S", (stat($distpath))[9]);

		$version = $versions[0];
		$description = "<pre style='font-size:9px;font-family:Monaco'>" . `$config->{"svn"} -r '{$svndate}:0' log --limit 20 $config->{"svn_full_url"}` . "</pre>";
		$svninfo = $self->latestSubversionInfoAtURL($config, $config->{"svn_full_url"}, $svndate);
	}

	my $revision = $svninfo->{"Last Changed Rev"};
	my $pubdate = Date::Format::time2str("%a, %d %b %Y %H:%M:%S %z", Date::Parse::str2time($svninfo->{"Last Changed Date"}));
	my $size = (stat($distpath))[7];
	my $dsasignature = `openssl dgst -sha1 -binary < "$distpath" | openssl dgst -dss1 -sign $config->{"dsa_key"} | openssl enc -base64`;
	chomp($dsasignature);

	return <<EOF;
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"> 
	<channel>
		<title>$project Appcast</title>
		<link>http://www.zankasoftare.com/sparkle/$file</link>
		<description>Most recent version available.</description>
		<language>en</language>
		<item>
			<title>$project $version->{"version"}</title>
			<description><![CDATA[$description]]></description>
			<pubDate>$pubdate</pubDate>
			<enclosure sparkle:version="$revision" sparkle:shortVersionString="$version->{"version"}" sparkle:dsaSignature="$dsasignature" url="$disturl" length="$size" type="application/octet-stream" />
		</item>
	</channel>
</rss>
EOF
}



sub latestSubversionInfoAtURL {
	my($self, $config, $url, $date) = @_;
	
	my @svninfos;
	my $info = "info";
	
	if($date) {
		$info .= " -r '{$date}'";
	}
	
	my @external_urls = $self->subversionExternalURLsAtURL($config, $url);

	push(@external_urls, $url);
	
	foreach (@external_urls) {
		my $svninfo = $self->subversionInfoAtURL($_);
		my $string = `$config->{"svn"} $info $_ 2>/dev/null`;
		
		if($string) {
			my %svninfo = map { /^(.+): (.+)$/ } split(/\n/, $string);

			push(@svninfos, \%svninfo) if $svninfo{"Last Changed Rev"};
		}
	}
	
	if(@svninfos == 0) {
		return;
	}
	
	@svninfos = sort { $b->{"Last Changed Rev"} <=> $a->{"Last Changed Rev"} } @svninfos;

	return $svninfos[0];
}



sub subversionExternalURLsAtURL {
	my($self, $config, $url) = @_;
	
	my $externals = `$config->{"svn"} pg svn:externals $url 2>/dev/null`;
	
	return unless $externals;
	
	my @externals = split(/\n/, $externals);
	my @external_urls;
	
	foreach (@externals) {
		my($path, $name) = split(/\s/);
		
		my $external_url;
		
		if($path =~ /^\^/) {
			$path =~ s/^\^//;
			$external_url = $config->{"svn_url"} . $path;
		}
		elsif($path =~ /^\.\./) {
			$path =~ s/^\.\.//;
			$external_url = $url;
			$external_url =~ s/(.+)\/(.+)/$1$path/;
		}
		
		if($external_url) {
			push(@external_urls, $external_url) if !grep { $external_url eq $_ } @external_urls;
			
			foreach $external_url ($self->subversionExternalURLsAtURL($config, $external_url)) {
				push(@external_urls, $external_url) if !grep { $external_url eq $_ } @external_urls;
			}
		}
	}
	
	return @external_urls;
}



sub subversionInfoAtURL {
	my($self, $url) = @_;
	
	my $string = `$self->{"config"}->{"current"}->{"svn"} info $url 2>/dev/null`;
		
	if($string) {
		my %svninfo = map { /^(.+): (.+)$/ } split(/\n/, $string);
		
		return \%svninfo if $svninfo{"Last Changed Rev"};
	}
}



sub currentHostOSAndArch {
	my($self) = @_;
	
	my $host = `hostname -s`;
	my $os = `uname -s`;
	
	chomp($host);
	chomp($os);

	my $arch;
	
	if($os eq "Darwin" || $os eq "Linux") {
		$arch = `arch`;
	}
	elsif($os eq "FreeBSD") {
		$arch = `uname -p`;
	}
	elsif($os eq "OpenBSD") {
		$arch = `machine`;
	}
	
	chomp($arch);
	
	return ($host, $os, $arch);
}



sub intervalStringForTime {
	my($self, $seconds) = @_;
	my $intervals = {days => 60*60*24, hours => 60*60, minutes => 60, seconds => 1};
	my $time = {};

	while($seconds > 0) {
		foreach ("days", "hours", "minutes", "seconds") {
			if($seconds >= $intervals->{$_}) {
				$time->{$_}++;
				$seconds -= $intervals->{$_};

				last;
			}
		}
	}

	my $string;

	foreach ("days", "hours", "minutes", "seconds") {
		if($time->{$_}) {
			$string .= ", " if $string;
			$string .= "$time->{$_} $_";
			$string =~ s/s$// if $time->{$_} == 1;
		}
	}

	return $string || "0 seconds";
}



sub compareVersionNumbers {
	my($self, $version1, $version2) = @_;
	
	$version1 =~ s/[^\d]//g;
	$version2 =~ s/[^\d]//g;
	
	$version1 *= 10 if $version1 < 100;
	$version2 *= 10 if $version2 < 100;
	
	return -1 if $version1 < $version2;
	return 1 if $version2 > $version1;
	return 0;
}

1;
