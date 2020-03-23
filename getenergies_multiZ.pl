#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Pod::Usage;
use Data::Dumper;
use Getopt::Long;
use Cwd qw(cwd);

$Data::Dumper::Sortkeys = 1;

#################

my($id, @Zlist, %Alist);
GetOptions(
    'z|Z|element=s'    => \$id,
    'help'             => \my $help,
    ) or die "\nCheck options and how to use: perl $0 -help\n\n";

pod2usage(-verbose => 1) if $help;

if($id){
    if($id eq 'ALL'){
	opendir my $dh, cwd() or die "$0: opendir: $!";
	my @subdirs = grep {-d $dh && ! /^\.{1,2}$/} readdir($dh);
	foreach (@subdirs){
	    if(/(\d+)-\w+-(\d+)/){
		push @Zlist, $1;
		$Alist{$1} = $2;
	    }	    
	}
    }elsif($id =~m /(\d+)-(\d+)/){
        foreach ($1 .. $2){
            push @Zlist, $_;
        }
    }
    my @tmp = split /,/ , $id;
    foreach (@tmp){
	unless ($id eq 'ALL'){
	    push @Zlist, $_ unless /-/;
	}
    }
}else{
    die print "\n Need to specify atoms. Check usage: perl $0 -help.\n\n";
}

foreach my $element (sort @Zlist){
    my $cmd = 'perl getenergies_singleZ.pl -z '.$element;
    $cmd .= ' -A '.$Alist{$element} if $id eq 'ALL';
    system($cmd);
}

# Usage messages when using "-help"

=pod
=head1 SYNOPSIS
    
    Get energies for several atoms and several vacancies. Output is printed/appended to file.
    Provide list of Z to run and per default the most abundant A-value is used. It is possible 
    to use option "-z ALL", which process all possible directories with the format "Z-NAME-A". 
    Output is printed/append to file.

    perl getenergies_multiZ.pl [options]

    Example: Extract all genergies for Z = 10,11,12,13
   
                perl getenergies_multiZ.pl -z 10,11,12,13
    
             OR
    
                perl getenergies_multiZ.pl -z 10-13


    Example: Extract energies for several atoms, not in consective order

                perl getenergies_multiZ.pl -z 10,Be,Mg,7,Ar,42-45

              
    Example: Extract energies for ALL calculations with existing subdirectories
    
                perl getenergies_singleZ.pl -z ALL

    
    
=head1 OPTIONS
   
    Use option for proton number (-z,-Z) to set list of atoms to extract bindingenergies for. 
    The provided massnumber (-a,-A,-mass) for isotope is per default used to the mass in a.m.u 
    of the neutral atom and the most abundant isotope. 

    -z,-Z            proton number (e.g. "-z 10" for neon) OR use "-z ALL" 

    -help            this help
=cut
