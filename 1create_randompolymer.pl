#!perl

#use strict;
use Getopt::Long;
use MaterialsScript qw(:all);

Tools->PolymerBuilder->ChangeSettings(Settings(
	ForceConcentrations => 'Yes', 
	UseProbabilities => 'No'));
my $randomCopolymer = Tools->PolymerBuilder->RandomCopolymer;
my $repeatUnit0 = Documents->Import("structures://repeat-units/acrylates/acrylonitrile.xsd");
my $repeatUnit1 = $Documents{"NBR_Cis-budiene.xsd"};
my $repeatUnit2 = $Documents{"NBR_Trans-budiene.xsd"};


$randomCopolymer->ClearRepeatUnits();
$randomCopolymer->AddRepeatUnit($repeatUnit0, 0.5, 0.5);
$randomCopolymer->AddRepeatUnit($repeatUnit1);
$randomCopolymer->AddRepeatUnit($repeatUnit2);


$randomCopolymer->SetConcentration(0, 0.6);
$randomCopolymer->SetConcentration(1, 0.08);
$randomCopolymer->SetConcentration(2, 0.32);


$randomCopolymer->SetReactivityRatio(0, 0, 1);
$randomCopolymer->SetReactivityRatio(0, 1, 0.5);
$randomCopolymer->SetReactivityRatio(0, 2, 0.5);
$randomCopolymer->SetReactivityRatio(1, 0, 1);
$randomCopolymer->SetReactivityRatio(1, 1, 1);
$randomCopolymer->SetReactivityRatio(1, 2, 0.5);
$randomCopolymer->SetReactivityRatio(2, 0, 0.5);
$randomCopolymer->SetReactivityRatio(2, 1, 0.5);
$randomCopolymer->SetReactivityRatio(2, 2, 1);

#Enter the number of chains in the $chain_number
for(my $chain_number = 10; $chain_number != 0; $chain_number = $chain_number-1)
{

#Enter the name of the folder at $doc
my $doc = Documents-> New ("$chain_number.xsd");

#For demo only - force the view to update
$doc->UpdateViews;
my $polymer = $randomCopolymer->Build($doc,10, , ,);

#Geometry Optimization
my $results = Modules->Forcite->GeometryOptimization->Run($doc, Settings(
	Quality => 'Medium', 
	CurrentForcefield => 'COMPASSIII', 
	AssignForcefieldTypes => 'Yes', 
	MaxIterations => 10000));

};



