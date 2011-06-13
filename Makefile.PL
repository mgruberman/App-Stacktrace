use 5.010_000;
use ExtUtils::MakeMaker;

if (! `which gdb`) {
    print "App::Stacktrace requires gdb. Aborting installation";
    exit 0;
}

WriteMakefile(
  ABSTRACT_FROM => 'lib/App/Stacktrace.pm',
  AUTHOR => 'Josh Jore <jjore@cpan.org>',
  EXE_FILES => [
    'bin/perl-stacktrace'
  ],
  $ExtUtils::MakeMaker::VERSION >= 6.30
      ? (LICENSE => 'perl')
      : (),
  NAME => 'App::Stacktrace',
  VERSION_FROM => 'lib/App/Stacktrace.pm',
);
