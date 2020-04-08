#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Time::Piece;
use Data::Dumper;
use List::Util qw(sum min max);
use File::Copy;
use Getopt::Long;
use Pod::Usage;

my @shells = ("s","p","d","f","g","h");

my %shell2orb = ('FO' => '1s', '' => '1s',      # add first two for FullOrbital e.g. no vacancy 
		 'K' => '1s',
		 'L1' => '2s', 'L23' => '2p',
		 'M1' => '3s', 'M23' => '3p', 'M45' => '3d', 
		 'N1' => '4s', 'N23' => '4p', 'N45' => '4d', 'N67' => '4f',
		 'O1' => '5s', 'O23' => '5p', 'O45' => '5d', 'O67' => '5f', 'O89' => '5g',
		 'P1' => '6s', 'P23' => '6p', 'P45' => '6d', 'P67' => '6f', 'P89' => '6g', 'P1011' => '6h',
		 'Q1' => '7s', 'Q23' => '7p',          
    );

# Dispatch list for subs - needed? 
my %action = (makeinp_rnucleus => \&makeinp_rnucleus,
	      makeinp_rcsfgenerate => \&makeinp_rcsfgenerate,
	      makeinp_rangular => \&makeinp_rangular,	      
	      makeinp_rwfnestimate => \&makeinp_rwfnestimate,
	      makeinp_rcsfblock => \&makeinp_rcsfblock,
	      makeinp_rmcdhf => \&makeinp_rmcdhf,
	      makeinp_rci => \&makeinp_rci,
	      makeinp_jj2lsj => \&makeinp_jj2lsj,
    );

sub makeinp_rnucleus{    
    my $z = shift;
    my $a = shift;

    my $filename = 'input_rnucleus';
    open my $FH,'>',$filename;
    
    my $inp = << 'END_INPUT';
$Z
$A
n
$A
1
1
1
END_INPUT

    $inp =~s/\$Z/$z/;
    $inp =~s/\$A/$a/g;
    
    print $FH $inp;
    close $FH;
    return $filename;

    
}

sub makeinp_rcsfgenerate{
    my $con = shift;
    my $vac = shift;
    print $con,"\t",$vac,"\n";
    
    my @orblst = split /\(\d+\)/, $con;                       # list of orbitals
    my %orb_occ = split /\((\d+)\)/, $con;                    # hash list of orbitals with occupation
#   unless($shell2orb{$vac} eq ''){
    unless($vac eq 'FO'){
	$orb_occ{$shell2orb{$vac}}-- if exists $shell2orb{$vac};  # -1 occupancy for vacancy

    }

    # Fix configuration
    my $conf;
    my %max_orb;
    foreach my $orb(@orblst){
	$orb =~m/(\d+)(.)/;
	$max_orb{$2} = $1;
	$conf .= $orb.'('.$orb_occ{$orb}.',i)' unless $orb_occ{$orb} == 0;
    }

    # Fix max orbitals
    my $orbs;
    foreach my $sh(@shells){
	if($max_orb{$sh}){
	    $orbs .= $max_orb{$sh}.$sh.',';
	}
    }
    $orbs =~s/,$//;
        
    # Fix resulting 2*J-number
    my $jj;
    if(sum(map { $orb_occ{$_} } keys %orb_occ) % 2 == 0){
	$jj = '0,20';
    }else{
	$jj = '1,21';
    }

    # Fix inputfile
    my $filename = 'input_rcsfgenerate';
    open my $FH,'>',$filename;   
    
    my $inp =  << 'END_INPUT';
*
0
$CONF

$ORBS
$JJ
0
n
END_INPUT
    
    $inp =~s/\$CONF/$conf/;
    $inp =~s/\$ORBS/$orbs/;
    $inp =~s/\$JJ/$jj/;
    
    print $FH $inp;
    close $FH;
    
    return $filename;
}

sub makeinp_rangular{
    my $filename = 'input_rangular';
    open my $FH,'>',$filename;
    
    my $inp = << 'END_INPUT';
y
END_INPUT
    
    print $FH $inp;
    close $FH;
    return $filename;
}

sub makeinp_rwfnestimate{
    my $filename = 'input_rwfnestimate';
    open my $FH,'>',$filename;

    my $inp = << 'END_INPUT';
y
2
*
END_INPUT

    print $FH $inp;
    close $FH;
    return $filename;
}

sub makeinp_rmcdhf{
    my $blockfile = shift;
    # Check block numbers (use output from rcsfblock program)    
    open my $FH_BLOCK,'<',$blockfile;
    my $readblock = 0;
    my $totalblock = 0;
    my $block;
    while(<$FH_BLOCK>){
	if($readblock){
	    ($totalblock, my $jp, my $ncsf) = split, / /;
	    $block .= "1-$ncsf\n";
	}
	$readblock = 1 if (/NCSF/);
    }
    close $FH_BLOCK;
    $totalblock > 1 ? $block .= "5" : chomp($block);

    my $filename = 'input_rmcdhf';
    open my $FH,'>',$filename;
    
    my $inp = << 'END_INPUT';
y
$BLOCK
*
*
1000
END_INPUT

    $inp =~s/\$BLOCK/$block/;
    
    print $FH $inp;
    close $FH;
    return $filename;
}

sub makeinp_rci{
    my $name = shift;
    my $con = shift; 
    my $blockfile = shift;

    # Get maxorb 
    my $maxorb = max (split /\w\(\d+\)/, $con);   
    
    # Check block numbers (use rcsfblock program and output from this)    
    open my $FH_BLOCK,'<',$blockfile;
    my $readblock = 0;
    my $totalblock = 0;
    my $block;
    while(<$FH_BLOCK>){
	if($readblock){
	    ($totalblock, my $jp, my $ncsf) = split, / /;
	    $block .= "1-$ncsf\n";
	}
	$readblock = 1 if (/NCSF/);
    }
    close $FH_BLOCK;

    my $filename = 'input_rci';
    open my $FH,'>',$filename;
    
    my $inp = << 'END_INPUT';
y
$NAME
y
y
1e-6
y
n
n
y
$MAXORB
$BLOCK
END_INPUT

    $inp =~s/\$NAME/$name/;
    $inp =~s/\$MAXORB/$maxorb/;
    $inp =~s/\$BLOCK/$block/;
    
    print $FH $inp;
    close $FH;
    return $filename;
}

sub makeinp_rcsfblock{
    my $filename = 'input_rcsfblock';
    open my $FH,'>',$filename;
    
    my $inp = << 'END_INPUT';
n
END_INPUT
    
    print $FH $inp;
    close $FH;
    return $filename;    
}


sub makeinp_jj2lsj{
     my $name = shift;

     my $filename = 'input_jj2lsj';
    open my $FH,'>',$filename;
    
    my $inp = << 'END_INPUT';
$NAME
y
y
y
END_INPUT

    $inp =~s/\$NAME/$name/;
   
    print $FH $inp;
    close $FH;
    return $filename;        
}

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

sub run{ 
    my $FH = shift;
    my $type = shift;
    my $cmd = shift;
    my @arg = @_;

    my $time = localtime->cdate;
    
    if($type == 0){
	print $FH "$time \t system:     $cmd\n";
	return system($cmd);
    }elsif($type == 1){
	print $FH "$time \t sub:        $cmd(".join(",",@arg).")\n";  	
	return $action{$cmd}->(@arg);
    }else{
	print $FH "$time \t             $cmd\n";
	return;
    }
}

#################

my($id, $A, $vacancy, $Z, $element, $config, $dirname, $vacname, $calcname);
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
    $vacancy = 'FO' unless $vacancy;

    if($A =~s/\*//){
	print "For element $Z using average mass from all isotopes.\n";
    }
    
    $dirname = $Z.'-'.$element.'-'.$A;
    
    if($vacancy){
	die "\n ERROR: Vacancy '$vacancy' is not real. Typo? Redo! \n\n" unless exists $shell2orb{$vacancy};
	die "\n ERROR: Vacancy '$vacancy' not possible with given configuration. Try again! \n\n" unless $config =~m /$shell2orb{$vacancy}/;
	$vacname = $vacancy;
    }else{
	$vacname = 'FO';     # FullOrbitals 
    }
    
    $calcname = $dirname.'-'.$vacname;

}else{
    die print "\n Need to specify atom to run. Check usage: perl $0 -help.\n\n";
}


# Start logfile, check/create directories to use
mkdir $dirname, 0755 unless(-d $dirname);
chdir $dirname;
mkdir $vacname, 0755 unless(-d $vacname);
chdir $vacname;
mkdir "log", 0755 unless(-d "log");
open my $LF,'>','log/process_calc.log';

### Run sequence to calculate state. 
 # RNUCLEUS
print "===== RNUCLEUS START, Z=$Z =====\n";
my $inp_rnucle = run($LF,1,"makeinp_rnucleus",$Z,$A);
run($LF,0,"rnucleus < $inp_rnucle | tee log/rnucleus.out");

# RCSFGENERATE
print "===== RCSFGENERATE START, Z=$Z =====\n";
my $inp_rcsfge = run($LF,1,"makeinp_rcsfgenerate",$config,$vacancy);
#run($LF,0,"rcsfgenerate < $inp_rcsfge | tee log/rcsfgenerate.out");
run($LF,0,"rcsfgenerate2 < $inp_rcsfge | tee log/rcsfgenerate.out");
run($LF,0,"cp rcsf.out rcsf.inp");  

#RANGULAR
print "===== RANGULAR START, Z=$Z =====\n";
my $inp_rangul = run($LF,1,"makeinp_rangular");
run($LF,0,"rangular < $inp_rangul | tee log/rangular.out");

#RWFNESTIMATE
print "===== RWFNESTIMATE START, Z=$Z =====\n";
my $inp_rwfnes = run($LF,1,"makeinp_rwfnestimate");
run($LF,0,"rwfnestimate < $inp_rwfnes | tee log/rwfnestimate.out");

#RMCDHF
print "===== RMCDHF START, Z=$Z =====\n";
my $blockfile = run($LF,1,"makeinp_rcsfblock");         
run($LF,0,"rcsfblock < $blockfile | tee log/rcsfblock.out");
my $inp_rmcdhf = run($LF,1,"makeinp_rmcdhf","log/rcsfblock.out");
run($LF,0,"rmcdhf < $inp_rmcdhf | tee log/rmcdhf.out");
run($LF,0,"rsave $calcname");

#RCI
print "===== RCI START, Z=$Z =====\n"; 
my $inp_rci = run($LF,1,"makeinp_rci",$calcname, $config, "log/rcsfblock.out");
run($LF,0,"rci < $inp_rci | tee log/rci.out");

#JJ2LSJ
print "===== JJ2LSJ START, Z=$Z =====\n"; 
my $inp_jj2lsj = run($LF,1,"makeinp_jj2lsj",$calcname);
run($LF,0,"jj2lsj < $inp_jj2lsj | tee log/jj2lsj.out");

close $LF;

# Usage messages when using "-help"

=pod
=head1 SYNOPSIS
    
    Calculate single state vacancy for given atom. Per default most abundant isotope mass 
    used for calculation. If no vacancy provided, neutral atom (full orbital, FO) calculated

    perl calc_singlevac.pl [options]

    Example: Calculate 10-Ne-20 with vacancy in L2. Note it is not possible to distinguish 
             between L2 and L3, hence set the vacancy to L23. 
   
                perl calc_singlevac.pl -z 10 -a 20 -v L23
             OR 
                perl calc_singlevac.pl -element Ne -mass 20 -vacancy L23
    
    
=head1 OPTIONS
   
    Use EITHER option for proton number (-z,-Z) OR element (-element) to set what atom 
    to calculate. The provided massnumber (-a,-A,-mass) for isotope is used as the mass 
    in a.m.u of the neutral atom. If massnumber is omitted the most abundant isotop is 
    used for mass and mass number. If no vacancy is provided the calculation is done with 
    the neutral atom and result sorted in directory with "FO" (FullOrbitals) in name. 

    -z,-Z            proton number (e.g. "-z 10" for neon)
    -element         element (e.g. "-element Ar" for argon)
    -a,-A,-mass      massnumber of atom
    -v,-vacancy      vacancy in configuration e.g. K, L1, L23

    -help            this help
=cut
