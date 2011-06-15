package App::Stacktrace;

=head1 NAME

App::Stacktrace - Stack trace

=head1 SYNOPSIS

  perl-stacktrace [option] pid

    --help

=head1 DESCRIPTION

perl-stacktrace prints Perl stack traces of Perl threads for a given
Perl process. For each Perl frame, the full file name and line number
are printed.

=head1 API

=over

=item new

=item run

=back

=cut

use strict;
use Config ();
use English -no_match_vars;
use Getopt::Long ();
use Pod::Usage ();
use XSLoader ();
use File::Temp ();

our $VERSION = '0.01';

XSLoader::load(__PACKAGE__, $VERSION);

sub new {
    my $class = shift;
    my $self = {
        pid        => undef,
        version    => undef,
        arch       => undef,
        'exec'     => 1,
        @_
    };
    return bless $self, $class;
}

sub run {
    my $self = shift;

    $self->_read_arguments( @_ );

    my $script = $self->_custom_generated_script;
    if ($self->{m}) {
        print $script;
    }
    else {
        $self->_run_gdb($script);
    }

    return;
}

sub _read_arguments {
    my $self = shift;
    local @ARGV = @_;
    Getopt::Long::GetOptions(
        $self,
        help => sub {
            Pod::Usage::pod2usage(
                -verbose => 2,
                -exitcode => 0 );
        },
        'm',
        'exec',
        'version=s',
        'arch=s',
    )
      or Pod::Usage::pod2usage(
        -verbose => 2,
        -exitcode => 2 );
    if (1 == @ARGV && $ARGV[0] =~ /^\d+$/) {
        $self->{pid} = shift @ARGV;
    }
    if (@ARGV) {
        Pod::Usage::pod2usage( -verbose => 2, -exitcode => 2 );
    }
    unless ($self->{pid} || $self->{m}) {
    }

    return;
}


sub _custom_generated_script {
    my ($self) = @_;

    # TODO: generate this statically
    for my $dir ( @INC ) {
        my $file = "$dir/App/Stacktrace/perl_backtrace_raw.txt";
        if (-e $file) {
            return $self->_TODO_add_constants( $file );
        }
    }

    die "Can't locate perl-backtrace.txt in \@INC (\@INC contains: @INC)";
}

sub _TODO_add_constants {
    my ($self, $template_script) = @_;

    my $this_library = __FILE__;
    my $src = <<"TODO_preamble";
# !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
# This file is built by $this_library from its data.
# Any changes made here will be lost!
#
TODO_preamble

    my $offsets = App::Stacktrace::_perl_offsets();
    for my $name (sort keys %$offsets) {
        $src .= "set $name = $offsets->{$name}\n";
    }

    if ($Config::Config{usethreads}) {
        require threads;
        my $key = "threads::_pool$threads::VERSION";
        my $len = length $key;
        $src .= <<"THREADS";
set \$POOL_KEY = "$key"
set \$POOL_KEY_LEN = $len
THREADS
    }


    open my $template_fh, '<', $template_script
        or die "Can't open $template_script: $!";
    local $/;
    $src .= readline $template_fh;

    my $command = $self->_command_for_version;
    $src .= <<"INVOKE";
$command
detach
quit
INVOKE

    return $src;
}

sub _command_for_version {
    return
        $] >= 5.014     ? 'perl_backtrace_5_14_x' :
        $] >= 5.012     ? 'perl_backtrace_5_12_x' :
        $] >= 5.010     ? 'perl_backtrace_5_10_x' :
        $] >= 5.008_009 ? 'perl_backtrace_5_8_9'  :
        $] >= 5.008     ? 'perl_backtrace_5_8_x'  :
        die 'Support for perl-5.6 or earlier not implemented';
}

sub _run_gdb {
    my ($self, $src) = @_;

    # TODO: what are the failure modes of File::Temp?
    my $tmp = File::Temp->new(
        UNLINK => 0,
        SUFFIX => '.gdb',
    );
    my $file = $tmp->filename;

    print { $tmp } $src;
    $tmp->flush;
    $tmp->sync;

    my @cmd = (
        'gdb',
            '-quiet',
            '-batch',
            '-nx',
            '-p', $self->{pid},
            '-x', $file,
    );
    if ($self->{exec}) {
        exec @cmd;
    }
    else {
        system @cmd;
        my $sig_num = $? & 127;
        my $core    = $? & 128;
        my $rc      = $? >> 8;

        warn "@cmd killed by signal $sig_num" if $sig_num;
        warn "@cmd core dumped" if $core;
    }
}

q{Bartender, I'll have a Gordon Freeman on the rocks, thanks.}