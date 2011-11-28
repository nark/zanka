package Config::INI::Simple;

use strict;
use warnings;

our $VERSION = '0.01';

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto || 'Config::INI::Simple';

	my $self = {
		__file__    => undef,
		__default__ => 'default',
		__eol__     => "\n",
		__append__  => 1,
		@_,
	};

	bless ($self,$class);
	return $self;
}

sub reset {
	my ($self) = @_;

	$self = {
		__file__    => $self->{__file__},
		__default__ => $self->{__default__},
		__eol__     => $self->{__eol__},
		__append__  => $self->{__append__},
	};
}

sub read {
	my ($self,$file) = @_;

	if (!defined $file) {
		$file = $self->{__file__};
		return unless defined $file;
	}

	return unless -e $file;

	$self->{__file__} = $file;

	open (FILE, $file);
	my @lines = <FILE>;
	close (FILE);
	chomp @lines;

	my $data = {};
	my $block = $self->{__default__} || 'default';

	foreach my $line (@lines) {
		$line =~ s/\r//g;
		$line =~ s/\n//g;
		if ($line =~ /\s*\[(.*?)\]\s*/) {
			$block = $1;
			next;
		}

		next if $line =~ /^\s*\;/;
		next if $line =~ /^\s*\#/;

		next if length $line == 0;
		my ($what,$is) = split(/=/, $line, 2);
		$what =~ s/^\s*//g;
		$what =~ s/\s*$//g;
		$is =~ s/^\s*//g;
		$is =~ s/\s*$//g;

		$data->{$block}->{$what} = $is;
	}

	foreach my $block (keys %{$data}) {
		$self->{$block} = $data->{$block};
	}

	return 1;
}

sub write {
	my ($self,$file) = @_;

	if (!defined $file) {
		$file = $self->{__file__};
		return unless defined $file;
	}

	return unless -e $file;

	open (FILE, $file);
	my @lines = <FILE>;
	close (FILE);
	chomp @lines;

	my $block = $self->{__default__} || 'default';
	my @new = ();
	my $used = {};

	foreach my $line (@lines) {
		if ($line =~ /\s*\[(.*?)\]\s*/) {
			$block = $1;
			$line =~ s/^\s*//g;
			$line =~ s/\s*$//g;
			push (@new, $line);
			next;
		}

		if ($line =~ /^\s*\;/ || $line =~ /^\s*\#/) {
			push (@new, $line);
			next;
		}

		if (length $line == 0) {
			push (@new, '');
			next;
		}

		my ($what,$is) = split(/=/, $line, 2);
		$what =~ s/^\s*//g;
		$what =~ s/\s*$//g;
		$is =~ s/^\s*//g;
		$is =~ s/\s*$//g;

		if (exists $self->{$block}->{$what}) {
			$line = join ('=', $what, $self->{$block}->{$what});
			$used->{$block}->{$what} = 1;
		}

		push (@new, $line);
	}

	# Add new config variables?
	if ($self->{__append__} == 1) {
		foreach my $key (keys %{$self}) {
			next if $key =~ /^__.*?__$/i;
			print "Checking key $key (ref = " . ref($key) . ")\n";

			if (!exists $used->{$key}) {
				print "Block doesn't exist!\n";
				push (@new, "");
				push (@new, "[$key]");
			}

			foreach my $lab (keys %{$self->{$key}}) {
				if (!exists $used->{$key}->{$lab}) {
					print "Adding $lab=$self->{$key}->{$lab} to INI\n";
					push (@new, "$lab=$self->{$key}->{$lab}");
				}
			}
		}
	}

	my $eol = $self->{__eol__} || "\r\n";
	open (WRITE, ">$file");
	print WRITE join ($eol, @new);
	close (WRITE);

	return 1;
}

1;
__END__

=head1 NAME

Config::INI::Simple - Simple reading and writing from an INI file--with preserved
comments, too!

=head1 SYNOPSIS

  # in your INI file
  ; The name of the server block to use
  ; Use one of the blocks below.
  server = Server01

  ; All server blocks need a host and port.
  ; These should be under each block.
  [Server01]
  host=foo.bar.com
  port=7775

  [Server02]
  host=foobar.net
  port=2235

  # in your Perl script
  use Config::INI::Simple;

  my $conf = new Config::INI::Simple;

  # Read the config file.
  $conf->read ("settings.ini");

  # Change the port from "Server02" block
  $conf->{Server02}->{port} = 2236;

  # Change the "server" to "Server02"
  $conf->{default}->{server} = 'Server02';

  # Write the changes.
  $conf->write ("settings.ini");

=head1 DESCRIPTION

Config::INI::Simple is for very simplistic reading and writing of INI files. A new object must
be created for each INI file (an object keeps all the data read in from an INI which is used
on the write method to write to the INI). It also keeps all your comments and original order
intact.

=head1 INI FILE FORMAT

A basic INI format is:

  [Block1]
  VAR1=Value1
  VAR2=Value2
  ...

  [Block2]
  VAR1=Value1
  VAR2=Value2
  ...

Comments begin with either a ; or a # and must be on their own line. The object's hashref
will contain the variables under their blocks. The default block is "default" (see B<new> for
defaults). So, B<$conf->{Block2}->{VAR2} = Value2>

=head1 METHODS

=head2 new

Creates a new Config::INI::Simple object. You can pass in certain settings here:

B<__file__> - Sets the file path of the INI file to read. If this value is set, then B<read>
and B<write> won't need the FILE parameter.

B<__default__> - Sets the name of the default block. Defaults to 'default'

B<__eol__> - Set the end-of-line characters for writing an INI file. Defaults to Win32's \n

B<__append__> - Set to true and new hash keys will be appended to the file upon writing. If a
new block is added to the hashref, that block will be appended to the end of the file followed
by its data. Defaults to 1.

=head2 read (FILE)

Read data from INI file B<FILE>. The object's hashref will contain this INI file's contents.

=head2 write (FILE)

Writes to the INI file B<FILE>, inputting all the hashref variables found in the object.

=head2 reset

Resets the internal hashref of the INI reader object. The four settings specified with B<new>
will be reset to what they were when you created the object. All other data is removed from
memory.

=head1 CHANGES

  Version 0.01
  - Initial release.

=head1 AUTHOR

C. J. Kirsle <kirsle -at- rainbowboi.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by A. U. Thor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
