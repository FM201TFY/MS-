#!perl

use strict;
use Getopt::Long;
use MaterialsScript qw(:all);

my $acConstruction = Modules->AmorphousCell->Construction;

for (my $n = 1; $n<21 ; $n++) {
my $doc1 =  Documents->Import("library://20250416_differentACN_Dreiding/POLYMER/20ACN/20ACN  Script/$n.xsd");
$acConstruction->AddComponent($doc1);
$acConstruction->Loading($doc1) = 1;


my $doc2 = Documents->Import("library://20250416_differentACN_Dreiding/POLYMER/ACM5050/create_ACM_EABA5050_dreiding  Script/$n.xsd");
$acConstruction->AddComponent($doc2);
$acConstruction->Loading($doc2) = 1;

}

my $results = $acConstruction->Run(Settings(
	Temperature => 300, 
	Quality => 'Medium',
	OptimizeGeometry => 'Yes', 
	Configurations => 1, 
	TargetDensity => 1.2, 
	LoadingMoves => 200, 
	CheckCloseContacts => 'Yes', 
	CloseContactvdWScale => 0.25, 
	NumberBiasedTorsionSteps => 100, 
	NumberBiasedHeadSegmentSteps => 100, 
	LookAhead => 2, 
	'3DPeriodicElectrostaticSummationMethod' => 'Atom based', 
	CurrentForcefield => 'Dreiding',
	AssignForcefieldTypes => 'Yes',
	ChargeAssignment => 'Use current'));
my $outTrajectory = $results->Trajectory;


