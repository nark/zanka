use strict;
package RTF::Config;
use Exporter;
use vars qw(@EXPORT @ISA $OS $LOG_FILE $LOG_CMD);
@ISA = qw(Exporter);
@EXPORT = qw($LOG_CMD $LOG_FILE $OS);


# Some stuff borrowed to CGI.pm
unless ($OS) {
  unless ($OS = $^O) {
    require Config;
    $OS = $Config::Config{'osname'};
  }
}
if ($OS=~/Win/i) {
  $OS = 'WINDOWS';
} elsif ($OS=~/vms/i) {
  $OS = 'VMS';
} elsif ($OS=~/Mac/i) {
  $OS = 'MACINTOSH';
} elsif ($OS=~/os2/i) {
  $OS = 'OS2';
} else {
  $OS = 'UNIX';
  $LOG_CMD = "| sort -d "; #$LOG_FILE";
}

1;
__END__
