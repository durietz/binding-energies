#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Pod::Usage;
use Data::Dumper;
use Getopt::Long;

#################

my($id, @calclist);
GetOptions(
    'z|Z|element=s'    => \$id,
    'help'             => \my $help,
    ) or die "\nCheck options and how to use: perl $0 -help\n\n";

pod2usage(-verbose => 1) if $help;

if($id){
    if($id =~m /(\d+)-(\d+)/){
	foreach ($1 .. $2){
	    push @calclist, $_;
	}
    }
    my @tmp = split /,/ , $id;
    foreach (@tmp){
	push @calclist, $_ unless /-/;
    }    
}else{
    die print "\n Need to specify atoms to run. Check usage: perl $0 -help.\n\n";
}

# Calculate stuff 
foreach my $element (@calclist){        
    my $cmd = 'perl calc_multivac.pl -z '.$element;
    system($cmd);
}

# Usage messages when using "-help"

=pod
=head1 SYNOPSIS
    
    Do calculation for several atoms using the massnumber for most abundant istope and
    all possible vacancies (including full orbital, FO). List atoms to calculate either 
    with Z or element name. Separate list with ',' or if many consecutive use '-'. 

    If calculations failed, print/append to logfile. 

    perl calc_listZ.pl [options]

    Example: Calculate all vacancies for C, N, O and Ne. 
   
                perl calc_listZ.pl -z C,N,O,Ne 
              
             OR

                perl calc_listZ.pl -z 6,N,8,Ne

            OR

                perl calc_listZ.pl -Z 6-8,10
    
=head1 OPTIONS
   
    Use EITHER option for proton number (-z,-Z) OR element (-element) to set what atom 
    to calculate. 

    -z,-Z            proton number (e.g. "-z 10" for neon)
    -element         element (e.g. "-element Ar" for argon)

    -help            this help
=cut
