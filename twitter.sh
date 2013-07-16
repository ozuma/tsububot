#!/bin/sh
export MODULEBUILDRC="$HOME/local/.modulebuildrc"
export PERL_MM_OPT="INSTALL_BASE=$HOME/local"
export PERL5LIB="$HOME/local/lib/perl5:$HOME/local/lib/perl5/i386-freebsd-64int:$HOME/local/lib/perl5/site_perl/5.8.9:$HOME/local/lib/perl5/site_perl/5.8.9/mach:$HOME/local/lib/perl5/5.8.9/mach:$PERL5LIB"

PROCESS=`echo $0`
MY_DIR=`dirname $PROCESS`

cd $MY_DIR
./main.pl

