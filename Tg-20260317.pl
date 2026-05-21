#!perl

use strict;
use Getopt::Long;
use MaterialsScript qw(:all);
use constant TRUE 	=> 1;
use constant FALSE 	=> 0;
use constant DEBUG	=> 2; # larger is more verbose
use constant PICO_TO_FEMTO => 1000;

#########################################################################################################################
#########################################################################################################################

# input xsd file
my $xsdDocName			= "500K";	# Name of xsd file
my $xsdDoc;
eval{ $xsdDoc = Documents->ActiveDocument; };

if ($@) # no active doc - use parameters defined above
{
	$xsdDoc	= $Documents{"$xsdDocName.xsd"};
} 

# Simulation settings
my $forcefield		 	= "Dreiding";		# COMPASSIII, Dreiding, pcff, cvff, Universal......
my $charges			= "Use current";	# when choose COMPASSIII, you can input Forcefield assigned
my $timeStep			= 1;			# Dynamics time step in fs
my $chargeMethod 		= "Atom based";		# Atom based, Group based or Ewald
my $Quality			= "Medium";		# Coarse/Medium/Fine/Ultra Fine
my $thermostat			= "Nose";		# Andersen, Nose(Defauft), Velocity Scale, Berendsen or NHL
my $Barostat			= "Berendsen";		# Andersen, Berendsen(Defauft), Parrinello, Souza-Martins 
my $Temperature			= 300;			# Main temperature throughout
my $Pressure			= 0.0001;		# Main pressure throughout
my $ensemble			= "NPT";		# Normally NPT, but use NVT if eg liquid slab with vacuum layer
							# if non-periodic NVT will be used in any case

my $add_tri			= FALSE;		# whether output .xtd file
my $one_time_equilibration	= 100;			# ps of dynamics for initial equilibration
my $TrajectoryFrequency		= 0.1;			# Take the conformation at intervals of several ps = 0.1*1000


#Counters for optimization and dynamics steps
my $geomoptcounter = 0;
my $step; #Number of iteration steps
my $mdcounter = 0;

#define input datas
my $initial_temperature = 500;
my $ending_temperature = 200;
my $point = 12;
my $per_point_temperature = ($initial_temperature-$ending_temperature)/$point;
my $numberOfSteps_1 = 30*PICO_TO_FEMTO;
$step = $numberOfSteps_1;
my $trajectoryFrequency_1 = 1*PICO_TO_FEMTO;
my $thenumberofconformation = $numberOfSteps_1/$trajectoryFrequency_1;

#########################################################################################################################
#########################################################################################################################
# Initialize Forcite with settings to be used globally
my $textDoc = Documents->New("0Progress.txt");
my $Forcite = Modules->Forcite;

####################################################################################################################
# One time equilibration
if ($one_time_equilibration > 0)
{
	my $steps = ($one_time_equilibration * PICO_TO_FEMTO / $timeStep);
	$textDoc -> Append("\nOne-time equilibration\n");
	my $results = ForciteDynamics($xsdDoc,$steps,"NPT",(Temperature => $initial_temperature));
	$results -> Trajectory->Delete;			#this purpose is delete the produre of Trajectory
	my $results = ForciteDynamics($xsdDoc,$steps,$ensemble);
	$results->Trajectory->Delete;
}

############################################################################################################################
my $doc1 = $xsdDoc;
my $results1 = ForciteDynamics($doc1,$numberOfSteps_1,"NPT",(Temperature => $initial_temperature));	
my $outTrajectory = $results1->Trajectory;		#Filters a source object for the Trajectory it contains.
my $outTrajectoryname = $outTrajectory->Name = "$initial_temperature K";

#define input datas to select Traj
my $initial_frame = 1;  #
my $numberOfSteps_2 = 30*PICO_TO_FEMTO;
my $trajectoryFrequency_2 = 1*PICO_TO_FEMTO;
my $thenumberofconformation_2 = $numberOfSteps_2/$trajectoryFrequency_2;
my $total_frame = $thenumberofconformation_2+1;
my $Thetimeintervaloftheoutputconformation = $trajectoryFrequency_2/PICO_TO_FEMTO; #ps
my $Thenumberofoutputconformations = 1; #hope the number of output conformations
my $selfaddnum = ($total_frame-$initial_frame+1)/$Thenumberofoutputconformations;


#########################################################################################################
################################### Temperature ratio of decreasing ###################################
#########################################################################################################
my $relaxation_temperature = $initial_temperature-$per_point_temperature;

for (my $current_temperature = $relaxation_temperature; $current_temperature >= $ending_temperature; $current_temperature = $current_temperature-$per_point_temperature)
{
    my $read_currentTemperature = $current_temperature + $per_point_temperature;
    my $traj_name = "$read_currentTemperature K.xtd";

#select Traj
    for (my $current_frame = $initial_frame; $current_frame <= $total_frame; $current_frame = $current_frame + $selfaddnum)
   {
        #print ("this is in totalFrame:$total_frame \n");
        #print ("this is in current_frame:$current_frame \n");
        
        if ($current_frame == $total_frame)

        {
            #print ("this is in if totalFrame:$total_frame \n");
            #print ("this is in if current_frame:$current_frame \n");
            my $traj = $Documents{$traj_name};
            $traj->CurrentFrame = $current_frame;
            my $mol = $traj;
            my $xsd_file = $mol->SaveAs("$current_temperature"."_Frame_$current_frame".".xsd");
            my $current_time = $current_frame*$Thetimeintervaloftheoutputconformation;       
            print ("This is the conformation at the $current_time ps.\n");
            print ("\n");
            
            my $doc2 = $xsd_file;
            my $results2 = ForciteDynamics($doc2,$numberOfSteps_2,$ensemble,(Temperature => $current_temperature, WriteLevel => "Silent",));
            my $outTrajectory = $results2->Trajectory;
            my $outTrajectoryname = $outTrajectory->Name = "$current_temperature K";
            
        }
	#1 input document
	my $doc = $Documents{"$current_temperature K.xtd"};

	#2build std
	my $std = Documents->New("$current_temperature K.std");
	my $dataSheet = $std->ActiveSheet;
	my $unit1 = "K";
	my $unit2 = "g/cm3";
	my $unit3 = "Gpa";

	$dataSheet->ColumnHeading(0) = "Frame number";	
	$dataSheet->ColumnHeading(1) = "Model";
	$dataSheet->ColumnHeading(2) = "Temperature($unit1)";
	$dataSheet->ColumnHeading(3) = "Density($unit2)";
	$dataSheet->ColumnHeading(4) = "pressure($unit3)";

	#output data
	my $trajectory = $doc->Trajectory;
	my $XtdFrames = $trajectory->NumFrames;


 
	 for (my $i = 1; $i < $XtdFrames ; $i = $i + 1) 
	 { 
 	   $doc->Trajectory->CurrentFrame = $i;
 	   my $Doc_xsd = Documents->New("$current_temperature K.xsd");
 	   $Doc_xsd->CopyFrom($doc);
	    my $Temperature = $doc->DisplayRange->PhysicalSystem->Temperature; 
	    my $Density = $doc->DisplayRange->SymmetrySystem->Density;
	    my $pressure = $doc->DisplayRange->SymmetrySystem->Pressure;

	    #input data
	    $dataSheet->Cell($i-1,0) = $i;
	    $dataSheet->Cell($i-1,1) = $Doc_xsd;
	    $dataSheet->Cell($i-1,2) = $Temperature; 
	    $dataSheet->Cell($i-1,3) = $Density; 
	    $dataSheet->Cell($i-1,4) = $pressure; 
    
	    $Doc_xsd->Discard;
	 }

    };

};


#########################################################################################################
#########################################################################################################
# Forcite dynamics
# Required globals: $Forcite, $textDoc, $mdcounter
# Usage: $results = ForciteDynamics($doc, $steps, $ensemble, (optionalSetting1 => 100, ...))

sub ForciteDynamics
{
	# Start the timer
	my $t0 = time;
	
	# Required arguments
	my $doc1 = shift;
	my $steps = shift;
	my $ensemble = shift;
	
	# Formulate the settings as a perl array
	my @settings = (
		NumberOfSteps	=> $steps,
		Ensemble3D	=> $ensemble,
		CurrentForcefield	=> $forcefield,
		ChargeAssignment	=> $charges,
		Quality			=> $Quality,
		Pressure		=> $Pressure,
		Thermostat		=> $thermostat,
		Barostat		=> $Barostat,
		TimeStep		=> $timeStep,
		TrajectoryFrequency	=> $TrajectoryFrequency*PICO_TO_FEMTO,
		WriteVelocities		=> "Yes",
		EnergyDeviation		=> 50000,
	);
	
	# The remainder are assumed to be custom settings
	push @settings, @_;
			
	# Run the dynamics inside an eval to prevent failed runs from stopping script
	my $results;
	eval 
	{
		$results = $Forcite->Dynamics->Run($doc1, \@settings);
	};
	if ($@) 
	{
		$textDoc->Append( "ERROR: ForciteDynamics failed\n");
		$textDoc->Append( $@);
		die "Failed in ForciteDynamics\n";
	}

	# Report time used
	if (DEBUG) 
	{ 
		$textDoc->Append(sprintf "ForciteDynamics %d steps, %s ensemble, %d seconds\n", 
			$steps, $ensemble, time-$t0);
		$textDoc->Save;
	}

	$mdcounter += $steps;
	return $results;	
}