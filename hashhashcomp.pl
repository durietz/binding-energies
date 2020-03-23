#/usr/bin/perl
use strict;
use warnings;
use Data::Dumper qw(Dumper);
 
my $filename = shift || 'ENERGIES-CALCULATED.DAT';
my %ele1;
my %orb;
my ($Z,$el,$A);
 
open my $fh, '<', $filename or die;
while (my $line = <$fh>) {
    chomp $line;
    if($line =~m /(\d+)-(\w+)-(\d+)/){
	($Z,$el,$A) = ($1,$2,$3);
	$Z = '00'.$Z if length($Z) == 1;
	$Z = '0'.$Z if length($Z) == 2;
    }else{
	my ($ORB, $E) = split /\s+/, $line;
	my $name =$Z."-".$el;
	unless($E =~m /No/){
	    $ele1{$name}{$ORB} = $E/1000 if ($E>0);
	}
    }
}
close $fh;

$filename = shift || 'BrIcc_Binding_Energies.txt';
my %ele2;

open $fh, '<', $filename or die;
while (my $line = <$fh>) {
    $line =~s/^\s+//; 
    chomp $line;
    #    print $line,"\n";
    if($line =~m /(\d+)-(\w+)-(\d+)/){
	($Z,$el,$A) = ($1,$2,$3);
	$Z = '00'.$Z if length($Z) == 1;
	$Z = '0'.$Z if length($Z) == 2;
    }else{
	my @data = split /\s+/, $line;
	my $ORB = $data[0];
#	print $ORB,"\n";
	for (my $i=1; $i < scalar @data; $i++) {
	    $ORB = $data[0].$i unless $data[0] eq 'K';
	    my $name =$Z."-".$el;
	    $ele2{$name}{$ORB} = $data[$i];
	}
    }
}
close $fh;


$filename = shift || 'Compare_BrIcc_Grasp_Ratio.txt';
open $fh, '>', $filename or die;
foreach my $name (sort keys %ele2) {
    print $fh $name,"\n";
    foreach my $orb (sort keys $ele2{$name}) {
	my $EB = $ele2{$name}{$orb};
	my $EG = '';
	my $EGEB = '';
	if($ele1{$name}{$orb}){
	    $EG = $ele1{$name}{$orb};
	    $EGEB = $EG/$EB;
	    printf $fh "%s\t %9.4f\t %14.9f\t %15.9f\n",$orb,$EB,$EG,$EGEB;
	}else{
	    printf $fh "%s\t %9.4f\n",$orb,$EB;
	}
    }
}
close $fh;


$filename = shift || 'Compare_Grasp_BrIcc_Ratio.txt';
open $fh, '>', $filename or die;
foreach my $name (sort keys %ele1) {
    print $fh $name,"\n";
    foreach my $orb (sort keys $ele1{$name}) {
	my $EB = '';
	my $EG = $ele1{$name}{$orb};
	my $EGEB = '';
	if($ele2{$name}{$orb}){
	    $EB = $ele2{$name}{$orb};
	    $EGEB = $EG/$EB;
	    printf $fh "%s\t %14.9f\t %9.4f\t %15.9f\n",$orb,$EG,$EB,$EGEB;
	}else{
	    printf $fh "%s\t %14.9f\n",$orb,$EG;
	}
    }
}
close $fh;


#$Data::Dumper::Sortkeys = 1;
#print Dumper \%ele;
#print Dumper \%ele2;
