#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Pod::Usage;
use Data::Dumper;
use Getopt::Long;
use Time::Piece;

$Data::Dumper::Sortkeys = 1;

my %orb2shell = ('' => 'FO', 
		 '1s' => 'K',
		 '2s' => 'L1', '2p' => 'L23',
		 '3s' => 'M1', '3p' => 'M23', '3d' => 'M45', 
		 '4s' => 'N1', '4p' => 'N23', '4d' => 'N45', '4f' => 'N67',
		 '5s' => 'O1', '5p' => 'O23', '5d' => 'O45', '5f' => 'O67', '5g' => 'O89',
		 '6s' => 'P1', '6p' => 'P23', '6d' => 'P45', '6f' => 'P67', '6g' => 'P89', '6h' => 'P1011',
		 '7s' => 'Q1', '7p' => 'Q23',          
    );

sub get_config{
    my $id = shift;
    my @info;
    
    open my $FH,'<',"atomconfig_all.txt";
    while(<$FH>){
	my @spl = split,/ /;
	if($spl[0] eq $id or $spl[1] eq $id){
	    @info = @spl;
	}
    }
    close $FH;
    return @info;
}

sub get_vacancies{
    my $con = shift;
    
    my @vac;
    foreach my $key (sort keys %orb2shell){
	push @vac, $orb2shell{$key} if $con =~m /$key/;
    }
    
    return @vac;
}

#################

my($id, $A, $vacancy, $Z, $element, $config, $dirname, @vaclist);
GetOptions(
    'z|Z|element=s'    => \$id,
    'a|A|massno=s'     => \$A,
    'v|V|vacancy=s'    => \$vacancy,
    'help'             => \my $help,
    ) or die "\nCheck options and how to use: perl $0 -help\n\n";

pod2usage(-verbose => 1) if $help;

# Start and get/set info from input and/or file
if($id){
    my @info = get_config($id);
    die "\n Element $id not in list. Try again!\n\n" unless $info[0];    
    $Z = $info[0];
    $element = $info[1];
    $A = $info[2] unless $A;
    $config = $info[3]; 
    $vacancy = '' unless $vacancy;
    
    $dirname = $Z.'-'.$element.'-'.$A;
}else{
    die print "\n Need to specify atom to run. Check usage: perl $0 -help.\n\n";
}

if($vacancy){
    @vaclist = split /,/ , $vacancy;
}else{
    @vaclist  = get_vacancies($config);
}

# Calculate stuff 
foreach my $vac (@vaclist){        
    my $cmd = 'perl calc_singlevac.pl ';
    $cmd .= "-z $Z -A $A -v $vac";
    system($cmd);
}

# Check if calculations ok by *.cm file generated and size > 0.
# If not write to to logfile and remove failed subdirectory
my @failed;
my $outfile = 'FAILED-CALC.LOG';
my $time = localtime->cdate;
open my $FH,'>>',$outfile;
foreach my $vac (@vaclist){
    my $cmfile = $dirname.'/'.$vac.'/'.$dirname.'-'.$vac.'.cm';
    if(-z $cmfile){
	push @failed, $vac;
	system("rm -rf $dirname/$vac");
    }	
}
if(scalar @failed){
    print $FH "  ----- $time --> Failed calc: $dirname \t $config \n";
    foreach (@failed){print $FH "\t $_\n";}
}
close $FH;
system("rm -f $outfile") if (-z $outfile);


# Usage messages when using "-help"

=pod
=head1 SYNOPSIS
    
    Calculate multiple vacancies for given atom. Per default calculate ALL possible 
    vacancies. If calculations fail, printed/append to logfile and subdirectories 
    for vacancies/calculations not working removed. 

    Note: The fail-logfile is written in append mode.
    
    perl calc_multivac.pl [options]

    Example: Calculate multiple (all) vacancies for 10-Ne-20. 
   
                perl calc_multivac.pl -z 10
              
             Calculate K and L23 vacancy for 10-Ne-20
    
                perl calc_multivac.pl -element Ne -v K,L23
    
=head1 OPTIONS
   
    Use EITHER option for proton number (-z,-Z) OR element (-element) to set what atom 
    to calculate The provided massnumber (-a,-A,-mass) for isotope is used as the mass 
    in a.m.u of the neutral atom. If massnumber is omitted the most abundant isotop is 
    used for mass and mass number. If no vacancy is provided all possible vacancies are 
    calculated (included calculations for the neutral atom (full orbital, FO)). 

    -z,-Z            proton number (e.g. "-z 10" for neon)
    -element         element (e.g. "-element Ar" for argon)
    -a,-A,-mass      massnumber of atom
    -v,-vacancy      vacancy in configuration e.g. K, L1, L23

    -help            this help
=cut
