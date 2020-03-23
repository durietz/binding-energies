#! /usr/bin/perl
use strict;
use warnings;
use autodie;
use Pod::Usage;
use Data::Dumper;
use List::Util qw(sum);
use List::Util qw(min);
use List::Util qw(reduce);
use Time::Piece;
use Getopt::Long;
use Cwd qw(cwd);

$Data::Dumper::Sortkeys = 1;

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

my %shell2n = ('K' => 1, 
	       'L' => 2, 
	       'M' => 3, 
	       'N' => 4, 
	       'O' => 5, 
	       'P' => 6, 
	       'Q' => 7,
    );

my %shell2suborb = ('1' => 's ', 
		    '2' => 'p-', '3' => 'p ', 
		    '4' => 'd-', '5' => 'd ', 
		    '6' => 'f-', '7' => 'f ', 
		    '8' => 'g-', '9' => 'g ', 
		    '10' => 'h-', '11' => 'h ', 
    );

my %suborb_maxoccupancy =('s ' => 2,  
			  'p-' => 2, 'p ' => 4, 
			  'd-' => 4, 'd ' => 6, 
			  'f-' => 6, 'f ' => 8, 
			  'g-' => 8, 'g ' => 10,
			  'h-' => 10, 'h ' => 12, 
    );

my %suborb_max =('s' => 2,  
		 'p' => 6,
		 'd' => 10,
		 'f' => 14,
		 'g' => 18,
		 'h' => 22,
    );

# Dispatch list for subs
my %action = (get_config => \&get_config,
	      get_vacancy_match => \&get_vacancy_match,
	      makeinp_rmixextract => \&makeinp_rmixextract,
	      get_energies => \&get_energies,
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

sub get_vacancy_match{
    my $con = shift;
    my $vac = shift;
    die "\n Need to provide vacancy\n\n" unless $vac;

    # hash list of orbitals with occupation
    my %orb_occ = split /\((\d+)\)/, $con; 
    
    # Fix relativistic orbital occupancy
    my %relorb;   
    for my $orb(keys %orb_occ){
	if($orb =~m /s/){
	    $relorb{"$orb "} = 0 unless exists $relorb{"$orb "};
	}else{
	    $relorb{"$orb "} = 0 unless exists $relorb{"$orb "};
	    $relorb{"$orb-"} = 0 unless exists $relorb{"$orb-"}; 
	}

	# Fill suborbs. If both '-' and ' ' present first fill '-' 
	my @orbtype = split //, $orb;	
	foreach my $i (1 .. $orb_occ{$orb}){
	    if(exists($relorb{"$orb-"})){
		if($relorb{"$orb-"} lt $suborb_maxoccupancy{"$orbtype[1]-"}){
		    $relorb{"$orb-"}++; 
		}else{
		    $relorb{"$orb "}++;
		}
	    }else{
		$relorb{"$orb "}++;
	    }
	}
    }
    
    # Get matchlist based on orb configuration and occupany. If occupancy in suborb ' ' = 0 increse 
    # to account for coupling between '-' and ' ' orbs (e.g. 12C) else reduce suborboccupancy with 1. 
    #
    #   L23 for 11B  1s(2)2s(2)2p-(1)2p(0) --> matchlist: [''     , ''     ] for 2p-(0),2p(0)
    #   L23 for 12C  1s(2)2s(2)2p-(2)2p(0) --> matchlist: [2p-( 1), 2p ( 1)]
    #   L23 for 14N  1s(2)2s(2)2p-(2)2p(1) --> matchlist: [2p-( 1), 2p-( 2)] for 2p1(1),2p(0) 
    #   L23 for 16O  1s(2)2s(2)2p-(2)2p(2) --> matchlist: [2p-( 1), 2p ( 1)]
    #   L23 for 19OF 1s(2)2s(2)2p-(2)2p(3) --> matchlist: [2p-( 1), 2p ( 2)]
    #   L23 for 20Ne 1s(2)2s(2)2p-(2)2p(4) --> matchlist: [2p-( 1), 2p ( 3)] 

    my @match;
    for my $orb(keys %relorb){
	my ($orbtype) = $orb =~m /\d(.*)/;

	if($orb =~m /$shell2orb{$vac}/ and $vac ne 'FO'){ 
	    #print $orbtype,"\t",$orb,"\t",$relorb{$orb},"\t",$suborb_maxoccupancy{$orbtype},"\n";
	    my $occ;
	    if($relorb{$orb}){
		$occ = $relorb{$orb} - 1;
	    }else{
		my $tmporb = $orb =~s / /-/r;
		if($relorb{$tmporb} == 1){
		    $occ = -1;
		}else{
		    $occ = 1;
		}
	    }
	    
	    if($occ == 0){
		if($orb =~m /s/){
		    push @match,'';
		}elsif($orb =~m /-/){
		    push @match,'SPECIAL_3';
		}else{
		    $orb =~m /(\d)(\w)(.)/;
		    my $tmporb = $1.$2.'SPECIAL_2';
		    my $tmporbtype = $2.'-';
		    push @match,"$tmporb\\( $suborb_maxoccupancy{$tmporbtype}\\)";
		}
	    }elsif($occ == -1){
		push @match,'SPECIAL_1';
	    }else{
		push @match,"$orb\\( $occ\\)";
	    }
 	}
    }
    @match = '' unless(@match); # if nothing to match make sure not uninitialized

    #print Dumper \@match unless $vac eq 'FO';

    return @match;
}

sub makeinp_rmixextract{
    my $name = shift;
    my $cutoff = shift;

    my $filename = 'input_rmixextract';
    open my $FH,'>',$filename;

    my $inp = << 'END_INPUT';
$NAME
y
$CUT
y
END_INPUT

    $inp =~s/\$NAME/$name/;
    $inp =~s/\$CUT/$cutoff/;
     
    print $FH $inp;
    close $FH;
    return $filename;
}

sub get_energies{
    my $rmixlog = shift; 
    my $vacname = shift;
    my @matchlist = @_;

    # Fix so @match is in correct order when both '-' and ' ' orb present
    my @match;
    if(scalar @matchlist == 2){
	foreach my $m (@matchlist){
	    if($m =~m /-/ or $m =~m /SPECIAL_3/){
		$m =~s /SPECIAL_3//; 
		$match[0] = $m;
	    }else{
		$m =~s /SPECIAL_1//; 
		$m =~s /SPECIAL_2/-/; 
		$match[1] = $m; 
	    }
	}
    }else{
	@match = @matchlist;
    }

    #   print Dumper \@match unless $vacname eq 'FO';
    
    # Get the energies for vacancy using matchlist
    my(%mix1, %mix2);
    my $E = '';
    my $mix = '';

    open my $FH,'<',$rmixlog;
    my $read = 0;

    while(my $line = <$FH>){
	if($line =~m /Energy =.*(-\d*\.\d*)\s*Coefficients and CSF/){
	    $E = $1;
	    $read = 1;
	}elsif($read == 1){
	    if($line =~m /\s+\d+\s+(-?\d\.\d*)/){
		$mix = $1;
		$read = 2;
	    }elsif($line =~m /===/) {
		$read = 0;
	    }
	    
	}elsif($read == 2){
	    if($line =~m /$match[0]/){
		if(exists($mix1{$E})){
		    $mix1{$E} = $mix unless $mix < $mix1{$E};
		}else{
		    $mix1{$E} = $mix;
		}
	    }
	    
	    if(scalar @match == 2){
		if ($line =~m /$match[1]/){
		    if(exists($mix2{$E})){
			$mix2{$E} = $mix unless $mix < $mix2{$E};
		    }else{
			$mix2{$E} = $mix;
		    }
		}
	    }
	    $read--;

	    # Add energy for no match? In particular for open shells? Need to look into ...
	    # unless($line =~m /$match[0]/ and $line =~m /$match[1]/){
	    # 	$mix3{$E} = $mix;
	    # }
	}
    }
    close $FH;

    # Get values (uncomment the one to use)
    #    1. "purest" state configuration
    #    2. lowest energy 
    #    3. weighted sum of all state configurations? Need to fix! (compare with readtrans_rdr.pl)

    my %energy;
    my @vac = split // , $vacname;

    # 1. "purest" state configuration
    if(scalar @vac == 1){
	$energy{"$vac[0]"} = reduce { $mix1{$a} > $mix1{$b} ? $a : $b } sort keys %mix1;
    }elsif(scalar @vac == 2){
	$energy{"$vac[0]$vac[1]"} = reduce { $mix1{$a} > $mix1{$b} ? $a : $b } sort keys %mix1;
    }elsif(scalar @vac == 3){
	$energy{"$vac[0]$vac[1]"} = reduce { $mix1{$a} > $mix1{$b} ? $a : $b } sort keys %mix1;
	$energy{"$vac[0]$vac[2]"} = reduce { $mix2{$a} > $mix2{$b} ? $a : $b } sort keys %mix2;
    }elsif(scalar @vac == 5){
	$energy{"$vac[0]$vac[1]$vac[2]"} = reduce { $mix1{$a} > $mix1{$b} ? $a : $b } sort keys %mix1;
	$energy{"$vac[0]$vac[3]$vac[4]"} = reduce { $mix2{$a} > $mix2{$b} ? $a : $b } sort keys %mix2;
    }
    
    # Add energy for no match? Need to fix ...
    # $energy{"NO MATCH"} = reduce { $mix{$a} > $mix3{$b} ? $a : $b } keys %mix3;
    
    # 2. lowest energy
    ### %mix1 = reverse %mix1;
    ### %mix2 = reverse %mix2;
    ### if(scalar @vac == 1){
    ### 	$energy{$vac[0]} = min values %mix1;
    ### }elsif(scalar @vac == 2){
    ### 	$energy{"$vac[0]$vac[1]"} = min values %mix1;
    ### }elsif(scalar @vac == 3){
    ### 	$energy{"$vac[0]$vac[1]"} = min values %mix1;
    ### 	$energy{"$vac[0]$vac[2]"} = min values %mix2;
    ### }elsif(scalar @vac == 5){
    ### 	$energy{"$vac[0]$vac[1]$vac[2]"} = min values %mix1;
    ### 	$energy{"$vac[0]$vac[3]$vac[4]"} = min values %mix2;
    ### }

    # 3. weighted sum (need to fix)
    ###
    
    return %energy;
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

my($id, $A, $vacancy, $Z, $element, $config, $topdir, $dirname);
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
    
    if($A =~s/\*//){
	print "For element $Z use average mass from all isotopes.\n";
    }
    
    $dirname = $Z.'-'.$element.'-'.$A;
    
    if($vacancy){
	die "\n ERROR: Vacancy '$vacancy' is not real. Typo? Redo! \n\n" unless exists $shell2orb{$vacancy};
	die "\n ERROR: Vacancy '$vacancy' not possible with given configuration. Try again! \n\n" unless $config =~m/$shell2orb{$vacancy}/;
    }
}else{
    die print "\n Need to specify atom to run. Check usage: perl $0 -help.\n\n";
}

$topdir = cwd;

# Check subdirectories. If no refrence dir 'FO' abort. 
opendir my $dh, $dirname or die "$0: opendir: $!";
my @subdirs = grep {-d "$dirname/$_" && ! /^\.{1,2}$/} readdir($dh);
exit print "\n No directory for neutral calculation found (full orbitals, 'FO').\n\n" unless grep(/FO/, @subdirs);
# if only one vacancy specified
if($vacancy){
    @subdirs  = $vacancy;
    push @subdirs, 'FO';
}

my %en_all;
foreach my $vacname (@subdirs){        
    chdir $topdir;
    chdir "$dirname/$vacname";
    mkdir "log", 0755 unless(-d "log");
    open my $LF,'>','log/process_extract.log';
    
    my $name = $dirname.'-'.$vacname;
    my $cutoff = 0.5;
    my $rmixlog = "log/rmixextract-$vacname.out";
    
    # RMIXEXTRACT
    unless(-e $rmixlog){
	my $inp_rmixex = run($LF,1,"makeinp_rmixextract",$name,$cutoff);
	run($LF,0,"rmixextract_rdr < $inp_rmixex | tee $rmixlog");
    }
    
    # Get energies for matched suborbs
    my @match = get_vacancy_match($config,$vacname);
    my %energy = get_energies($rmixlog,$vacname,@match);

    # Add to big hash of energies    
    foreach my $key (keys %energy){
	if($energy{$key}){
	    $en_all{$key} = $energy{$key};
	}else{
	    $en_all{$key} = 0.0;
	}
    }
}

# Print values to screen and append to outfile
chdir $topdir;
my $time = localtime->cdate;
my $hartree2eV =  27.2113861612825;
my $outfile = 'ENERGIES-CALCULATED.DAT';
open my $FH,'>>',$outfile;

printf "--- $time \t Energies (eV):  $Z-$element-$A \t $config \n";
printf $FH "--- $time \t Energies (eV):  $Z-$element-$A \t $config \n";
foreach (sort { $en_all{$a} <=> $en_all{$b} } keys %en_all) {
    if($en_all{$_}){
	printf "%-8s %s\n", $_, $hartree2eV*($en_all{$_}-$en_all{'FO'}) unless $_ eq 'FO';
	printf $FH "%-8s %s\n", $_, $hartree2eV*($en_all{$_}-$en_all{'FO'}) unless $_ eq 'FO';
    }else{
	printf "%-8s %s\n", $_, "No value found" unless $_ eq 'FO';
	printf $FH "%-8s %s\n", $_, "No value found" unless $_ eq 'FO';
    }
}
close $FH;

# Usage messages when using "-help"

=pod
=head1 SYNOPSIS
    
    Get energies for given atom and vacancies. Output is printed/appended to file.
    For vacancies note e.g. L2 does not exist, use L23. 

    perl getenergies_singelZ.pl [options]

    Example: Extract all bindingenergies for 10-Ne-20. Assume calculations for all possible vacancies done. 
   
                perl getenergies_singleZ.pl -z 10
              
    Example: Extract bindingenergy for L1 in 10-Ne-20. 
    
                perl getenergies_singleZ.pl -element Ne -v L1
    
    
=head1 OPTIONS
   
    Use EITHER option for proton number (-z,-Z) OR element (-element) to set what atom 
    to extract bindingenergies for. The provided massnumber (-a,-A,-mass) for isotope is used 
    as the mass in a.m.u of the neutral atom. If massnumber is omitted the most abundant isotop 
    is used for mass and mass number. 

    If no vacancy is provided the extraction is done for all calculated vacancies. Note it is
    necessary the calculations for the neutral atom (full orbital, FO) is present. 

    -z,-Z            proton number (e.g. "-z 10" for neon)
    -element         element (e.g. "-element Ar" for argon)
    -a,-A,-mass      massnumber of atom
    -v,-vacancy      vacancy in configuration e.g. K, L1, L23

    -help            this help
=cut
