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
# Run dynamics at initial temperature to generate starting trajectory for cooling process
$textDoc->Append("\n=== Initial temperature point: $initial_temperature K ===\n");
my $doc1 = $xsdDoc;
my $results_initial = ForciteDynamics($doc1, $numberOfSteps_1, $ensemble, (Temperature => $initial_temperature));
my $initialTrajectory = $results_initial->Trajectory;
$initialTrajectory->Name = "$initial_temperature K";
$textDoc->Append("Initial trajectory created: $initial_temperature K.xtd\n");
$textDoc->Save;

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
}

#########################################################################################################
################################### Calculate Tg from density-temperature data ###########################
#########################################################################################################
$textDoc->Append("\n=== Calculating Tg from density-temperature data ===\n");
$textDoc->Save;

my $summaryStd = Documents->New("Tg_Summary.std");
my $summarySheet = $summaryStd->ActiveSheet;
$summarySheet->ColumnHeading(0) = "Temperature (K)";
$summarySheet->ColumnHeading(1) = "Density (g/cm3)";
$summarySheet->ColumnHeading(2) = "Specific Volume (cm3/g)";
$summarySheet->ColumnHeading(3) = "Std Dev (g/cm3)";

my @temperatures;
my @avgDensities;
my @specificVolumes;
my @stdDeviations;
my $rowIndex = 0;

for (my $temp = $initial_temperature; $temp >= $ending_temperature; $temp -= $per_point_temperature)
{
    my $stdFileName = "$temp K.std";
    if (exists $Documents{$stdFileName})
    {
        my $tempStd = $Documents{$stdFileName};
        my $tempSheet = $tempStd->ActiveSheet;
        my $numRows = $tempSheet->RowCount;
        
        if ($numRows > 0)
        {
            my $startRow = int($numRows * 0.5);
            my $sumDensity = 0;
            my $sumDensity2 = 0;
            my $count = 0;
            
            for (my $r = $startRow; $r < $numRows; $r++)
            {
                my $density = $tempSheet->Cell($r, 3);
                if (defined $density && $density > 0)
                {
                    $sumDensity += $density;
                    $sumDensity2 += $density * $density;
                    $count++;
                }
            }
            
            if ($count > 0)
            {
                my $avgDensity = $sumDensity / $count;
                my $variance = ($sumDensity2 / $count) - ($avgDensity * $avgDensity);
                my $stdDev = sqrt(abs($variance));
                my $specificVolume = 1.0 / $avgDensity;
                
                push @temperatures, $temp;
                push @avgDensities, $avgDensity;
                push @specificVolumes, $specificVolume;
                push @stdDeviations, $stdDev;
                
                $summarySheet->Cell($rowIndex, 0) = $temp;
                $summarySheet->Cell($rowIndex, 1) = sprintf("%.6f", $avgDensity);
                $summarySheet->Cell($rowIndex, 2) = sprintf("%.6f", $specificVolume);
                $summarySheet->Cell($rowIndex, 3) = sprintf("%.6f", $stdDev);
                $rowIndex++;
                
                $textDoc->Append(sprintf("T = %d K, Density = %.6f g/cm3, Sv = %.6f cm3/g\n", 
                    $temp, $avgDensity, $specificVolume));
            }
        }
    }
}

if (scalar(@temperatures) >= 4)
{
    my $n = scalar(@temperatures);
    my $midPoint = int($n / 2);
    
    my ($slope1, $intercept1) = linearFit(\@temperatures, \@specificVolumes, 0, $midPoint);
    my ($slope2, $intercept2) = linearFit(\@temperatures, \@specificVolumes, $midPoint, $n);
    
    if (defined $slope1 && defined $slope2 && abs($slope1 - $slope2) > 1e-10)
    {
        my $Tg = ($intercept2 - $intercept1) / ($slope1 - $slope2);
        
        $textDoc->Append("\n" . "=" x 60 . "\n");
        $textDoc->Append("GLASS TRANSITION TEMPERATURE (Tg) CALCULATION RESULTS\n");
        $textDoc->Append("=" x 60 . "\n");
        $textDoc->Append(sprintf("High-T region: Sv = %.6e * T + %.6f\n", $slope1, $intercept1));
        $textDoc->Append(sprintf("Low-T region:  Sv = %.6e * T + %.6f\n", $slope2, $intercept2));
        $textDoc->Append(sprintf("\n*** Calculated Tg = %.2f K ***\n", $Tg));
        $textDoc->Append("=" x 60 . "\n");
        
        my $TgStd = Documents->New("Tg_Result.std");
        my $TgSheet = $TgStd->ActiveSheet;
        $TgSheet->ColumnHeading(0) = "Parameter";
        $TgSheet->ColumnHeading(1) = "Value";
        $TgSheet->ColumnHeading(2) = "Unit";
        $TgSheet->Cell(0, 0) = "Tg"; $TgSheet->Cell(0, 1) = sprintf("%.2f", $Tg); $TgSheet->Cell(0, 2) = "K";
        $TgSheet->Cell(1, 0) = "High-T slope"; $TgSheet->Cell(1, 1) = sprintf("%.6e", $slope1); $TgSheet->Cell(1, 2) = "cm3/g/K";
        $TgSheet->Cell(2, 0) = "High-T intercept"; $TgSheet->Cell(2, 1) = sprintf("%.6f", $intercept1); $TgSheet->Cell(2, 2) = "cm3/g";
        $TgSheet->Cell(3, 0) = "Low-T slope"; $TgSheet->Cell(3, 1) = sprintf("%.6e", $slope2); $TgSheet->Cell(3, 2) = "cm3/g/K";
        $TgSheet->Cell(4, 0) = "Low-T intercept"; $TgSheet->Cell(4, 1) = sprintf("%.6f", $intercept2); $TgSheet->Cell(4, 2) = "cm3/g";
    }
    else
    {
        $textDoc->Append("Warning: Could not calculate Tg - slopes are too similar or undefined\n");
    }
}
else
{
    $textDoc->Append("Warning: Not enough data points to calculate Tg\n");
}

$textDoc->Save;

sub linearFit
{
    my ($tempRef, $svRef, $start, $end) = @_;
    my $n = $end - $start;
    
    if ($n < 2) { return (undef, undef); }
    
    my $sumX = 0; my $sumY = 0; my $sumXY = 0; my $sumX2 = 0;
    
    for (my $i = $start; $i < $end; $i++)
    {
        my $x = $tempRef->[$i];
        my $y = $svRef->[$i];
        $sumX += $x;
        $sumY += $y;
        $sumXY += $x * $y;
        $sumX2 += $x * $x;
    }
    
    my $denominator = $n * $sumX2 - $sumX * $sumX;
    if (abs($denominator) < 1e-10) { return (undef, undef); }
    
    my $slope = ($n * $sumXY - $sumX * $sumY) / $denominator;
    my $intercept = ($sumY - $slope * $sumX) / $n;
    
    return ($slope, $intercept);
}


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