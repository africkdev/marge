#!/usr/bin/env perl
use strict;
use warnings;

# Copyright Verena M. Link <vlink@ucsd.edu>
# 
# This file is part of MMARGE
#
# MMARGE is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# MMARGE is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.


use POSIX;
use Getopt::Long;
use Storable;
use Statistics::Basic qw(:all);
use config;
use general;
use analysis_tree;
use Set::IntervalTree;
use Data::Dumper;
use Memory::Usage;
use 5.014;
use Sys::CPU;

$_ = "" for my($genome, $file, $tf, $filename, $output, $ab, $plots, $overlap, $tmp_out, $data, $tmp_center, $genome_dir, $center_dist, $tf_dir_name, $longest_seq, $motif_measure, $GLMM_output);
$_ = () for my(@strains, %peaks, @split, @split_one, @split_two, %seq, %seq_far_motif, %seq_no_motif, %PWM, @fileHandlesMotif, %index_motifs, %tag_counts, %fc, %block, %ranked_order, %mut_one, %mut_two, %delta_score, %delete, %remove, %mut_pos_analysis, %dist_plot, %dist_plot_background, %motif_scan_scores, %lookup_strain, %last_strain, %tree, %peaks_recentered, %seq_recentered, @header_recenter, %recenter_conversion, $correlation, $pvalue, %wrong_direction, %right_direction, %middle_direction, %tf_for_direction, %num_of_peaks, @tf_dir, $seq, @strains_working, @Threads, @running, $current_thread);
$_ = 0 for my($hetero, $allele, $region, $delta, $keep, $mut_only, $tg, $filter_tg, $fc_significant, $mut_pos, $dist_plot, $effect, $center, $analyze_motif, $analyze_no_motif, $analyze_far_motif, $longest_seq_motif, $longest_seq_no_motif, $longest_seq_far_motif, $motif_diff, $motif_diff_percentage, $delta_tag, $delta_threshold, $delta_tick, $fc_low, $fc_high, $filter_no_mut, $filter_out, $print_block, $core, $rand_tmp_mut, $rand_tmp_dist, $no_correction);
my $line_number = 1;

sub printCMD {
        print STDERR "\n\nUsage:\n";
	print STDERR "\nRequired parameters:\n";
        print STDERR "\t-file <file>: annotated peak file (including tag counts)\n";
        print STDERR "\t-ind <individuals>: Comma-separated list of individuals - Order must overlay with order in annotated peak file\n";

	print STDERR "\nPeak file manipulation:\n";
	print STDERR "\t-center: centers peaks on TF specified in -AB (automatically analyzes sequences with motif in center - set -far_motif and/or -no_motif for analysis of these sequences)\n";
	print STDERR "\t-center_dist: Distance to peak center that motif can be away from (max) to still be centered on (default: 25bp)\n"; 
	print STDERR "\t-region: Size of the region used to look for other motifs (Default: 0 - peak is not extended)\n";
	print STDERR "\t-tg <minimal tag count>: Filters out all peaks with less than x tag counts\n";

	print STDERR "\nAdditional parameters for pairwise comparison:\n";
	print STDERR "\t-output: Name of the output files\n";
	print STDERR "\t-plots: Output name of the plots\n";
	print STDERR "\t-AB: Antibody that was used for this ChIP (to exclude mutations in this motif from analysis in the secound round). It is also required for centering peaks\n";
	print STDERR "\t-motif: analyzes sequences with TF motif (only works with -center - without centering on TF it is not possible to group the sequences in with motif/ far motif/ no motif)\n";

	print STDERR "\nAdditional output for pairwise comparison:\n";
	print STDERR "\t-tf_direction <list with TF>: (comma separated list) for each of these transcription factor 3 output files are printed (all peaks where mutation and loss of binding are in the same direction (same_direction_<TF>.txt), all peaks with mutations that are between significant fold change (direction_between_foldchanges_<TF>.txt) and all peaks where mutation and loss of binding are in the opposite direction (opposite_direction_<TF>.txt) - all: all motifs\n";
	print STDERR "\t-tf_dir_name <prefix>: Prefix for the naming of the files created by tf_direction option\n";
	print STDERR "\t-no_motif: analyzes sequences without TF motif\n";
	print STDERR "\t-far_motif: analyzes sequences with TF motif that are more that n bp away from peak center (default: 25 - different value can be defined in -center_dist)\n";
	print STDERR "\t-mut_only: just keeps peaks where one individuals is mutated\n";

	print STDERR "\nPlot options for pairwise comparison:\n";
	print STDERR "\t-mut_pos: Also analyzes the position of the motif that is mutated\n";
	print STDERR "\t-dist_plot: Plots distance relationships between TF and motif candidates\n";
	print STDERR "\t\t-effect: Just plots distance relationship for peaks that are affected\n";
 	print STDERR "\t-genome: Genome (Used for distribution plots to generate the background distributions)\n";

	print STDERR "\nAdditional parameters for all versus all comparison:\n";
	print STDERR "\t-GLMM_output <name>: Name of the output file from the GLMM analysis (default = GLMM_results.txt)\n";
	print STDERR "\t-measure [Motif|Motif_score]: For all versus all analysis. Either the existance of the motif (Motif) or the exact motif score (Motif_score) is considered in the GLMM (default: Motif)\n";

	print STDERR "\nOptional parameters - only change them if you are what you are doing:\n";
	print STDERR "\t-no_correction: Turns off multiple testing correction\n";
	print STDERR "\t-motif_diff <difference>: Difference in the motif score to count it as mutated motif (for pairwise analysis) - can either be a percentage or absolute number (please use % for percentage - default 50% - also turned on when only using -delta)\n";
	print STDERR "\t-delta_tag: Does not use fold change but delta of the tag counts between the individuals\n";
	print STDERR "\t-delta_threshold: Difference between tag counts that is counted as significant (default: 100)\n";
	print STDERR "\t-fc_pos: Fold change threshold to count peaks as strain specific vs not (Default: 2fold)\n";
	print STDERR "\t-overlap: Count motif as not mutated if the overlap n basepairs (complete|half|#bp)\n";
	print STDERR "\t-print_block: Outputs temproray data structure\n";

	print STDERR "\nAdditional options:\n";
        print STDERR "\t-hetero: Data is heterozygous\n";
	print STDERR "\t-core <number of cores for model calculation> (default 4): Is only used when more than 2 individuals are defined\n";
	print STDERR "\t-keep: keep temporary files\n";

	print STDERR "\nParameters to overwrite default paths:\n";
	print STDERR "\t-TF <file with PWM for transcription factors>: (default HOMERs all.motifs) \n";
	print STDERR "\t-data_dir <folder to data directory>: default defined in config\n";
	print STDERR "\t-genome_dir <folder to indivial genomes>: default defined in config\n";
	print STDERR "\n\n";
        exit;
}

#my $mu = Memory::Usage->new();
#my $start_mu = $mu->record('starting work');

if(@ARGV < 1) {
        &printCMD();
}

#Check mandatory command line arguments
my %mandatory = ('-file' => 1, '-ind' => 1);
my %convert = map { $_ => 1 } @ARGV;
config::check_parameters(\%mandatory, \%convert);

#Prepare commandline varibale for output in plots
my $commandline_tmp = $0 . " ". (join " ", @ARGV);
my $commandline = "\n\n\n\n\n\n\n\nCOMMAND:\n";
while(length($commandline_tmp) > 80) {
	$commandline .= substr($commandline_tmp, 0, 80) . "\n";
	$commandline_tmp = substr($commandline_tmp, 80);
}
$commandline .= $commandline_tmp;


GetOptions(     "genome=s" => \$genome,
                "file=s" => \$file,
                "ind=s{,}" => \@strains,
		"core=s" => \$core,
                "hetero" => \$hetero, 
		"-TF=s" => \$tf, 
		"-region=s" => \$region,
		"-delta" => \$delta, 
		"-output=s" => \$output,
		"-GLMM_output=s" => \$GLMM_output,
		"-delta_tag" => \$delta_tag,
		"-delta_threshold=s" => \$delta_threshold,
		"-plots=s" => \$plots,
		"-AB=s" => \$ab,
		"-tf_direction=s{,}" => \@tf_dir,
		"-tf_dir_name=s" => \$tf_dir_name,
		"-keep" => \$keep, 
		"-data_dir=s" => \$data,
		"-genome_dir=s" => \$genome_dir,
		"-motif_diff=s" => \$motif_diff,
		"-tg=s" => \$tg,
		"-no_correction" => \$no_correction,
		"-mut_only" => \$mut_only, 
		"-mut_pos" => \$mut_pos, 
		"-overlap=s" => \$overlap,
		"-fc_pos=s" => \$fc_significant, 
		"-dist_plot" => \$dist_plot, 
		"-effect" => \$effect,
		"-center" => \$center, 
		"-measure=s" => \$motif_measure,
		"-center_dist=s" => \$center_dist,
		"-motif" => \$analyze_motif,
		"-no_motif" => \$analyze_no_motif,
		"-print_block" => \$print_block,
		"-far_motif" => \$analyze_far_motif)
        or die("Error in command line options!\n");
#First step: Get the sequences for the peaks

#Set variables
if($genome_dir eq "" && $data eq "") {
	$genome_dir = config::read_config()->{'data_folder'};
	$data = config::read_config()->{'data_folder'};
}
if($genome_dir eq "") {
	$genome_dir = $data;
}

if($motif_measure eq "") {
	$motif_measure = "Motif";
}
if($motif_measure ne "Motif" && $motif_measure ne "Motif_score") {
	print STDERR "Unknown measurement for all vs. all\n";
	print STDERR "Measurement can be Motif or Motif_score\n";
	exit;
}

if($data eq "") {
	$data = config::read_config()->{'data_folder'};
}
if($delta_tag == 1 && $delta_threshold == 0) {
	$delta_threshold = 100;
}
if($delta == 1 && $motif_diff == 0) {
	$motif_diff_percentage = 0.5;
} 
$analyze_motif = 1;
if($center == 1 && $center_dist eq "") {
	$center_dist = 25;
}
if(($ab eq "" || $genome eq "" || $center == 0) && $dist_plot == 1) {
	print STDERR "Distance plots not possible without anchor TF (-AB), genome (-genome), and center (-center) for the motif\n";
	print STDERR "Do not generate distance plots!\n";
	print STDERR "Waiting for 10 seconds - if you want to abort and restart hit Ctrl + C\n";
	for(my $i = 0; $i < 10; $i++) {
		print STDERR ".";
		sleep(1);
	}
	print STDERR "\n";
	$dist_plot = 0;
	$effect = 0;
}
if($hetero == 0) {
	$allele = 1;
} else {
	$allele = 2;
}
if($effect == 1) { $dist_plot = 1; }
if($fc_significant == 0) {
	$fc_significant = 2;
}
if(substr($motif_diff, length($motif_diff) -1) eq "%") {
	$motif_diff_percentage = substr($motif_diff, 0, length($motif_diff) - 1)/100;
	$motif_diff = 0;
}
if($tf eq "") {
	$tf = config::read_config()->{'motif_file'}; 
}
#Check if strains were just separated by space
if(@strains == 1) {
	my @tmp = split(' ', $strains[0]);
	if(@tmp > @strains) {
		@strains = @tmp;
	} else {
		@tmp = split(",", $strains[0]);
		if(@tmp > @strains) {
			@strains = @tmp;
		}
	}
}

for(my $i = 0; $i < @strains; $i++) {
	$strains[$i] =~ s/,//g;
	$strains[$i] = uc($strains[$i]);
}

#if(@strains > 2 && $core == 0) {
#	$core = 4;
#}
if($core == 0) { $core = 1; }
my $system_core = Sys::CPU::cpu_count();
if($system_core < $core) {
	print STDERR "Your system has only " . $system_core . " cores\n";
	print STDERR "You specified " . $core . " cores\n";
	print STDERR "Adjusting number of cores to maximal system cores!\n";
	$core = $system_core;
}

if($dist_plot == 1) {
	$rand_tmp_dist = rand();
}
if($mut_pos == 1) {
	$rand_tmp_mut = rand();
}

if(@strains > 2 && $core < 4) {
	print STDERR "Only $core used for an all vs. all comparison\n";
	print STDERR "These comparisons take a long time - more cores are recommended\n";
	print STDERR "Do you want to proceed?\n";
	print STDERR "Waiting for 10 seconds\n";
	for(my $i = 0; $i < 10; $i++) {
		print STDERR ".";
		sleep(1);
	}
	print STDERR "\nContinuing....\n";
}

#Save motif files
my ($index_motif_ref, $PWM_ref, $score_ref) = analysis::read_motifs($tf);
%index_motifs = %$index_motif_ref;
%motif_scan_scores = %$score_ref;
print STDERR "Save index file\n";
#$mu->record('read_motifs');

#Add motifs to direction hash
if(@tf_dir == 1 && $tf_dir[0] eq "all") {
	foreach my $motif (keys %index_motifs) {
		$tf_for_direction{$motif} = 1;
	}
} else {
	for(my $i = 0; $i < @tf_dir; $i++) {
		$tf_dir[$i] =~ s/,//g;
		$tf_for_direction{$tf_dir[$i]} = 1;
	}
}


if($ab ne "") {
	if(!exists $index_motifs{$ab}) {
		print STDERR "TF specified in -AB does not exist in motif file\n";
		print STDERR "Please double check your motif file!\n";
		print STDERR "Here is a list of all motifs in your motif file:\n";
		foreach my $keys (sort {$a cmp $b} keys %index_motifs) {
			print "\t" . $keys . "\n";
		}
		exit;
	}
}
%PWM = %$PWM_ref;

print STDERR "Saving peaks\n";
open FH, "<$file" or die "Can't open $file!\n";
my @allele_independent;
foreach my $line (<FH>) {
	chomp $line;
	if(substr($line, 0, 1) eq "#" || substr($line, 0, 6) eq "PeakID" || substr($line, 0, 2) eq "ID") {
		next;
	}
	$line_number++;
	@split = split('\t', $line);
	for(my $i = @split - @strains; $i < @split; $i++) {
		if(!($split[$i] =~ /^-?\d+\.?\d*$/)) {
			print STDERR "This is not an annotated peak file!\n";
			exit;
		} 
	}
	if($tg > 0) {
		$filter_tg = 0;
		for(my $i = @split - @strains; $i < @split; $i++) {
			if($split[$i] > $tg) {
				$filter_tg = 1;
			} 
		}	
		if($filter_tg == 0) {
			$filter_out++;
			next;
		}
	}
	#If the chromsome is annotated with allele (because of mapping) - remove the allele information
	@allele_independent = split("_", $split[1]);
	$split[1] = $allele_independent[0];
	$peaks{substr($split[1], 3)}{$split[2]} = $split[3];
	$tag_counts{substr($split[1], 3)}{$split[2]} = "";		
	$fc{substr($split[1], 3)}{$split[2]} = "";
	for(my $i = @split - (@strains * $allele); $i < @split; $i++) {
		$tag_counts{substr($split[1], 3)}{$split[2]} .= $split[$i] . "\t";
	}
	#Save foldchange 
	if($delta_tag == 0) {
		for(my $i = @split - (@strains * $allele); $i < @split - 1; $i++) {
			for(my $j = $i + 1; $j < @split; $j++) {
				$fc{substr($split[1], 3)}{$split[2]} .= log(($split[$i]+1)/($split[$j]+1))/log(2) . "\t";
			} 
		}
	#Save differences between tag counts not ratio
	} else {
		for(my $i = @split - (@strains * $allele); $i < @split - 1; $i++) {
			for(my $j = $i + 1; $j < @split; $j++) {
				$fc{substr($split[1], 3)}{$split[2]} .= ($split[$i] - $split[$j]) . "\t";
			}
		}
	}
}
close FH;
#$mu->record('after save peaks');
if($line_number == 1) {
	print STDERR "File was empty!\n";
	print STDERR "No peaks are saved!\n";
	exit;
}

if($filter_out > 0) {
	print STDERR "" . $filter_out . " peaks out of " . $line_number . " (" . sprintf("%.2f", (($filter_out/$line_number) *100)) . "%) filtered because of low tag counts\n";
	$line_number = $line_number - $filter_out;
	print STDERR "Continue with " . $line_number . " peaks\n\n";
}
print STDERR "Loading shift vectors\n";

for(my $i = 0; $i < @strains; $i++) {
	print STDERR "\t\t" . $strains[$i] . "\n";
	my($tree_ref, $last, $lookup) = general::read_strains_data($strains[$i], $data, "ref_to_strain");
	$tree{$strains[$i]} = $tree_ref;
	$lookup_strain{$strains[$i]} = $lookup;
	$last_strain{$strains[$i]} = $last;
}
#$mu->record('saved strains data');

#Get all sequences from file and save them in hash
&get_files_from_seq();

#Center peaks - if not set save seq in seq_recentered for downstream analysis

if($center == 1) {
	&center_peaks();
} else {
	$analyze_no_motif = 0;
	$analyze_far_motif = 0;
	%seq_recentered = %{$seq};
	$num_of_peaks{'motif'} = $line_number;
}

if(!exists $num_of_peaks{'motif'}) {
	print STDERR "Motif specified in -AB (" . $ab . ") was not found in any peaks!\n";
	print STDERR "Are you sure you used the correct antibody?\n";
	print STDERR "Exiting...\n";
	exit;
}

my $tmp_out_main_motif = "tmp" . rand();
print STDERR "tmp out main motif: " . $tmp_out_main_motif . "\n";
if($plots eq "") {
	$plots = "output_mut";
}
if($output eq "") {
	$output = "output_motif";
}
if($GLMM_output eq "") {
	$GLMM_output = "GLMM_results.txt";
}	

if($analyze_motif == 1) {
	print STDERR "Run analysis for all sequences with " . $ab . " motif\n";
	if($tmp_center ne "") {
		$tmp_out = $tmp_center . ".recentered_motif";
	}
	$longest_seq = $longest_seq_motif;
	&screen_and_plot($output . "_with_motif", $plots . "_with_motif", $tmp_out, $tmp_out_main_motif . "_with_motif", $longest_seq_motif, \%seq_recentered, $num_of_peaks{'motif'});
}

if($analyze_no_motif == 1) {
	print "analyze no motif\n";
	print STDERR "Run analysis for all sequences without " . $ab . " motif\n";
	$longest_seq = $longest_seq_no_motif;
	&screen_and_plot($output . "_without_motif", $plots. "_without_motif", $tmp_center . ".no_motif", $tmp_out_main_motif . "_no_motif", $longest_seq_no_motif, \%seq_no_motif, $num_of_peaks{'no'}, 1);
}

if($analyze_far_motif == 1) {
	print "analyze far motif\n";
	print STDERR "Run analysis for all sequences with " . $ab . " motif that is not in the peak center\n";
	$longest_seq = $longest_seq_far_motif;
	&screen_and_plot($output . "_with_far_motif", $plots . "_with_far_motif", $tmp_center . ".far_motif", $tmp_out_main_motif . "_far_motif", $longest_seq_far_motif, \%seq_far_motif, $num_of_peaks{'far'});
}
if($keep == 0) {
	print STDERR "Delete output files\n";
	foreach my $d (keys %delete) {
		`rm $d`
	}
}

#$mu->dump();
sub get_files_from_seq{
        $tmp_out = "tmp" . rand();
        $delete{$tmp_out} = 1;
        my ($seq_ref, $l_seq, $filter) = analysis::get_seq_for_peaks($tmp_out, \%peaks, \@strains, $genome_dir, $allele, $line_number, $mut_only, $region, \%tree, \%lookup_strain, \%last_strain);
	$seq = $seq_ref;
	#Important for distance plots
	$longest_seq_motif = $l_seq;
	$filter_no_mut = $filter;
}

#main logic of the script
sub screen_and_plot{
	my $output = $_[0];
	my $plots = $_[1];
	my $tmp_out = $_[2];
	my $tmp_out_main_motif = $_[3];
	my $longest_seq = $_[4];
	my $seq = $_[5];
	my $no_motif = 0;
	my $seq_considered = $_[6];
#	$seq_considered = $seq_considered - $filter_no_mut;
	if(@_ > 7) {
		$no_motif = 1;
	}
	#Scan sequences with HOMER scanMotifGenome
	#Fork this:
	my $split_motifs = ceil((keys %index_motifs)/$core);
	my $count = 0;
	my @split_array;
	foreach my $key (sort {$a cmp $b} keys %index_motifs) {
		$split_array[$count] = $key;
		$count++;
	}
	my @save_motifs;
	my $run = 0;
	my $k = 0;
	for(my $i = 0; $i < @split_array; $i = $i + $split_motifs) {
		$k = 0;
		for(my $j = $run * $split_motifs; $j < ($run + 1) * $split_motifs; $j++) {
			$save_motifs[$run][$k] = $split_array[$j];
			$k++;
		}
		$run++;
	}
	my $count_fork = 0;
	for(1 .. $core) {
		my $pid = fork;
		if(not $pid) {
			&process_motifs_for_analysis(\@{$save_motifs[$count_fork]}, $output, $seq, $count_fork);
			exit();
		}
		$count_fork++;
	}
	my $pid = fork;
	if(not $pid) {
		&monitor_processes();
		exit();
	}
	for (1 .. ($core+1)) {
		wait();
	}
	print STDERR "\n\n";
	print STDERR "Done with scanning and processing motifs\n";
	foreach my $motif (keys %index_motifs) {
		$delete{$output . "_" . $motif . ".txt"} = 1;
	}

	if(@strains > 2) {
		my $group;
		my %skipped;
		my $filename;
		#Write GLMM scripts per core that will be used
		my @motif_array;
		foreach my $motif (keys %index_motifs) {
			push @motif_array, $motif;
			print STDERR $motif . "\n";
		}
		my $part = int((@motif_array)/$core) + 1;
		my $end_index;
		my %data_for_threading;
		for(my $i = 0; $i < $core; $i++) {
			open OUT, ">GLMM_script_" . $output . "_" . ($i + 1) . ".R";
			$delete{"GLMM_script_" . $output . "_" . ($i + 1) . ".R"} = 1;
			$data_for_threading{$i} = "GLMM_script_" . $output . "_" . ($i + 1) . ".R";
			print OUT "library(lme4)\n";
			if($part * ($i + 1) > @motif_array) {
				$end_index = @motif_array;
			} else {
				$end_index = $part * ($i + 1);
			}
			for(my $j = $i * $part; $j < $end_index; $j++) {
				$filename = $output . "_" . $motif_array[$j] . ".txt";
				#Make sure there are several grouping levels
				if(!-e $filename) {
					print STDERR $motif_array[$j] . " does not exist - no motif was found.\n";
					print STDERR "Skipping...\n";
					$skipped{$motif_array[$j]} = 1;
					next;
				}
				$group = `cat $filename | awk '{print \$5}' | sort -u | wc -l`;
				chomp $group;
				if($group == 2) { 
					print STDERR $motif_array[$j] . " does not have enough levels for a GLMM\nskipping...\n"; 
					$skipped{$motif_array[$j]} = 1; 
					next; 
				}
				$group = `wc -l $output\_$motif_array[$j].txt`;
				
				if((split('\s+', $group))[0] < @strains + 2) {
					print STDERR $motif_array[$j] . " is only found in one genomic location\nNot enough levels for GLMM\nskipping...\n";
					$skipped{$motif_array[$j]} = 1;
					next;
				}
				print OUT "print(\"" . $motif_array[$j] . " in thread " . $i . " (" . $i . " of " . $end_index . " (" . ($j/$end_index) . "%))\")\n";
				print OUT $motif_array[$j] . " <- read.delim(\"" . $filename . "\", header=T)\n";
				$delete{$filename} = 1;
				print OUT "write(\"Calculating model for " . $motif_array[$j] . "\", stderr())\n";
				if($motif_measure eq "Motif") {
					print OUT "mod_" . $motif_array[$j] . " <- lmer(binding ~ Motif + (1 | Locus) + (1| Strain), data=" . $motif_array[$j] . ")\n";
				} else {
					print OUT "mod_" . $motif_array[$j] . " <- lmer(binding ~ Motif_score + (1 | Locus) + (1| Strain), data=" . $motif_array[$j] . ")\n";
				}
				print OUT "pvalue_" . $motif_array[$j] . " <- drop1(mod_" . $motif_array[$j] . ",test=\"Chisq\")\n";
				print OUT "print(\"" . $motif_array[$j] . "\")\n";
				print OUT "pvalue_" . $motif_array[$j] . "\n";
			}
			close OUT;
		}
		my $count_fork = 0;
		for(1 .. $core) {
			my $pid = fork;
			if(not $pid) {
				my $file_thread = $data_for_threading{$count_fork};
				my $command = "Rscript " . $file_thread . " > output_" . substr($file_thread, 0, length($file_thread) - 2) . ".txt";
				print $command . "\n";
				`$command`;
				exit;
			}
			$count_fork++;
		}
		for (1 .. $core) {
			wait();
		}
		print STDERR "Done with waiting for forks\n";
		print "Done with waiting for forks\n";
		open GLMM, ">$GLMM_output";
		print GLMM "Motif\tp-value\n";
		my %save_pvalues;
		my $m_name;
		for(my $i = 0; $i < $core; $i++) {
			my $output_file = "output_" . substr($data_for_threading{$i}, 0, length($data_for_threading{$i}) - 2) . ".txt";
			print STDERR "Analyzing $output_file\n";
			open FH, "<$output_file";
			foreach my $line (<FH>) {
				chomp $line;
				if(substr($line, 0, 3) eq "[1]") {
					$m_name = substr($line, 5, length($line) - 6);
					next;
				}
				@split = split('\s+', $line);
				if(($line ne "" && @split > 1) && ($split[0] eq "Motif" || $split[0] eq "Motif_score")) {
					if(@split < 5) {
						$save_pvalues{1}{$m_name} = 1;
					} elsif($split[4] eq "<") {
						$save_pvalues{$split[5]}{$m_name} = 1;
					} else {
						$save_pvalues{$split[4]}{$m_name} = 1;
					}
				}
			}
			close FH;
		}
		foreach my $pvalue ( sort {$a <=> $b } keys %save_pvalues ) {
			foreach my $motif_name (keys %{$save_pvalues{$pvalue}}) {
				if($no_correction == 1) {
					print GLMM $motif_name . "\t" . $pvalue . "\n";
				} else {
					print GLMM $motif_name . "\t" . ($pvalue * (keys %index_motifs)) . "\n"; 
				}
			}
		}
		foreach my $motifs (keys %skipped) {
			print GLMM $motifs . "\t1\n";
		}
		close GLMM;
	} else {
		#Writes output file per motif for further analysis
		print STDERR "Generating R files for all!\n";
		&generate_R_files($plots . ".R", $output, $seq_considered);
	}

	if($mut_pos == 1) {
		foreach my $motifs (keys %index_motifs) {
			%{$mut_pos_analysis{$motifs}} = %{retrieve("tmp_storage_mut_pos_" . $rand_tmp_mut . "_" . $motifs . ".txt")};
			$delete{"tmp_storage_mut_pos_" . $rand_tmp_mut . "_" . $motifs . ".txt"} = 1;
		}
		&generate_mut_pos_analysis_file($plots . "_mut_pos_motifs.R");
	}
	if($dist_plot==1) {
		my $bg_folder = config::read_config()->{'motif_background_path'};
		my ($delete_ref, $dist_plot_background_ref) = analysis::background_dist_plot($bg_folder, \%index_motifs, \%delete, \%motif_scan_scores, $genome, $ab, $region, $longest_seq, $core);
		%delete = %{$delete_ref};
		%dist_plot_background = %{$dist_plot_background_ref};
		foreach my $motifs (keys %index_motifs) {
			%{$dist_plot{$motifs}} = %{retrieve("tmp_storage_dist_" . $rand_tmp_dist . "_" . $motifs . ".txt")};
			$delete{"tmp_storage_dist_" . $rand_tmp_dist . "_" . $motifs . ".txt"} = 1;
		}
		&generate_dist_plot($plots . "_distance.R", $no_motif, $longest_seq);	
	}
	#Run a second round where mutation main TF is excluded
	if($ab ne "") {
		#Not possible at this point for all vs all, because we do not analyze in detail which motifs are mutated, only how well motif score and tag count correlate
		if(@strains > 2) { 
			print STDERR "ChIP AB is defined\n";
			print STDERR "No analysis run for peaks without mutated PU.1 motif\n";	
			last;
		} else {
			my $considered = 0;
			#check mutation summary file for chipped antibody and remove all peaks with one or more mutated motifs
			open FH, "<", $output . "_" . $ab . ".txt";
			foreach my $line (<FH>) {
				chomp $line;
				@split = split('\t', $line);
				if($split[-3] > 0 || $split[-2] > 0) {
					$remove{$split[1]} = 1;
					$seq_considered--;
				}
			}
			@fileHandlesMotif = ();
			my ($fileHandlesMotif_ref, $delete_ref) = analysis::open_filehandles(\%index_motifs, \%delete, $output . "_removed");
			%delete = %$delete_ref;
			@fileHandlesMotif = @$fileHandlesMotif_ref;
			#Remove all positions from the files with mutations in chipped motif
			foreach my $key (keys %index_motifs) {
				open FH, "<", $output . "_" . $key . ".txt";
				my $filename  = $output . "_removed_" . $key . ".txt";
				$delete{$filename} = 1;
				open my $fh, ">", $filename or die "Can't open $filename: $!\n";
				$fileHandlesMotif[$index_motifs{$key}] = $fh;
				foreach my $line (<FH>) {
					chomp $line;
					@split = split("\t", $line);
					if(!exists $remove{$split[1]}) {
						$fileHandlesMotif[$index_motifs{$key}]->print($line . "\n");
					}
				}
				if(exists $right_direction{$key}) {
					print STDERR $key . "\n";
					foreach my $remove_pos (keys %remove) {
						if(exists $right_direction{$key}{$remove_pos}) {
							delete $right_direction{$key}{$remove_pos};
						}
					}
				}
				if(exists $middle_direction{$key}) {
					foreach my $remove_pos (keys %remove) {
						if(exists $middle_direction{$key}{$remove_pos}) {
							delete $middle_direction{$key}{$remove_pos};
						}
					}
				}
				if(exists $wrong_direction{$key}) {
					foreach my $remove_pos (keys %remove) {
						if(exists $wrong_direction{$key}{$remove_pos}) {
							delete $wrong_direction{$key}{$remove_pos};
						}
					}
				}
			}
			&generate_R_files($plots . "_removed.R", $output . "_removed", $seq_considered);
		}
	}
}

sub process_motifs_for_analysis{
	my @fork_motifs = @{$_[0]};
	my $output = $_[1];
	my $seq = $_[2];
	my $c = $_[3];
	my %block;
	my $dist_plot_thread = ();
	my $mut_pos_thread = ();
	my $motifs;
#	my $tmp_out = "tmp" . rand(15);
	my $tmp_motif_file;
	my $tmp_file;
	my $rand_folder;
	$rand_folder = "threading_" . rand() . "_" . $c;
	my $command = "mkdir -p " . $rand_folder;
	`$command`;
	my $pwd = `pwd`;
	chomp $pwd;
	for(my $i = 0; $i < @fork_motifs; $i++) {
		if(!defined $fork_motifs[$i]) { next; }
		$motifs = $fork_motifs[$i];
		$tmp_motif_file = $tmp_out . "_" . $motifs . ".txt";
		open OUT, ">$tmp_motif_file";
		print OUT ">" . $motifs . "\t" . $motifs . "\t" . $motif_scan_scores{$motifs} . "\n";
		foreach my $pos (sort {$a <=> $b} keys %{$PWM{$motifs}}) {
			print OUT $PWM{$motifs}{$pos}{'A'} . "\t" . $PWM{$motifs}{$pos}{'C'} . "\t" . $PWM{$motifs}{$pos}{'G'} . "\t" . $PWM{$motifs}{$pos}{'T'} . "\n";
		}
		close OUT;
		$tmp_file = "tmp_file_" . $tmp_out . "_" . $motifs . ".txt";
	#	sleep($c);		
		analysis::scan_motif_with_homer($tmp_out, $tmp_file, $tmp_motif_file, $rand_folder, $pwd); 
		#Analyze the motifs between the different strains and save convert the output file into a has$allele, h
		%block = ();
		my ($block_ref) = analysis::analyze_motifs($tmp_file, \@strains, \%tree, \%lookup_strain, \%last_strain, $allele, $region);
		%block = %$block_ref;
		#Merge the hash (when overlap is set, merge the overlapping motifs, calculate motif score if motif was not found)
		$block_ref = analysis::merge_block(\%block, $overlap, \@strains, $seq, \%tree, \%lookup_strain, \%last_strain, $allele);
		%block = %$block_ref;
	#		$mu->record('merged all motifs in block');
		if($print_block == 1) {
			my $tmp_b = Dumper %block;
			print STDERR $tmp_b . "\n";
		}
		analysis::output_motifs(\%block, $output . "_" . $motifs . ".txt", \%tag_counts, \@strains, \%index_motifs, \%fc, \%recenter_conversion, $motif_diff, $motif_diff_percentage, $allele);
		if($dist_plot == 1) {
			#Check background distribution
			my ($dist_plot_thread) = analysis::distance_plot(\%block, \@strains, \%fc, $fc_significant, $effect, $longest_seq, $seq, $delta_tag, $delta_threshold, $allele);
			store $dist_plot_thread, "tmp_storage_dist_" . $rand_tmp_dist . "_" . $motifs . ".txt";
		}
		if($mut_pos == 1) {
			my ($mut_pos_thread) = analysis::analyze_motif_pos(\%block, \%fc, \@strains, $fc_significant, $seq, \%tree, \%last_strain, \%lookup_strain, $motif_diff, $motif_diff_percentage, $delta_tag, $delta_threshold, $allele, $region);
			store $mut_pos_thread, "tmp_storage_mut_pos_" . $rand_tmp_mut . "_" . $motifs . ".txt";
		}
		if($delta == 1) {
			&generate_delta_files($output, $plots . "_delta.R");
		}
		if(@strains > 2) {
			analysis::all_vs_all_comparison(\%block, \%recenter_conversion, \%tag_counts, \@strains, $allele, \%motif_scan_scores, $output);
		}
		if($keep == 0) {
			`rm $tmp_motif_file`;
			`rm $tmp_file`;
		}
	}
	$command = "rm -rf $rand_folder";
	`$command`;
}

#Generate distance plots
sub generate_dist_plot{
	$_ = 0 for my($first, $max_ab, $max);
	$_ = () for my($legend_col, $legend_class, $second_factor, $motif_print, %second_factor, $max_second);
	$_ = "" for my($x, $y, $max_main);
	my $output = $_[0];
	my $no_motif = $_[1];
	my $longest_seq = $_[2];
	print STDERR "Creating R script for $output\n";
	open R, ">$output";
	my $strain_number = 1;
#	my $tmp_ab = &motif_name($ab);
	my $tmp_ab = analysis::get_motif_name($ab);
	#longest seq is needed for x axis
	if($longest_seq % 2 == 1) {
		$longest_seq++;
	}
	$x = "x <- c(";
#	for(my $i = 0; $i < $longest_seq + $region; $i++) {
	for(my $i = 0; $i < $longest_seq; $i++) {
		$x .= ($i - int($longest_seq/2)) . ",";
	}
	if(length($x) > 8) {
		chop $x;
	}
	#### Write R-File output
	$x .= ")";
	print R "pdf(\"" . substr($output, 0, length($output) - 2) . ".pdf\", width=10, height=5)\n";
	print R "plot(0, 0, xlim=c(0,0), ylim=c(0,0), main=\"" . $commandline . "\", bty=\'n\', xaxt=\"n\", yaxt=\"n\", col=\"white\", xlab=\"\", ylab=\"\")\n";
	print R $x . "\n";
	#Generate colors
	print R "color <- colorRampPalette(c(\"blue\", \"red\"))(" . (@strains) . ")\n";
	#First generate vectors for main TF
	$max_main = "max_main <- max(";
	foreach my $strain (keys %{$dist_plot{$ab}}) {
		$y = $tmp_ab . "_" . $strain . " <- c(";
		$max_main .= $tmp_ab . "_" . $strain . ",";
		for(my $i = 0; $i < $longest_seq; $i++) {
			if(!exists $dist_plot{$ab}{$strain}{$i}) {
				$y .= "0,";
			} else {
				$y .= $dist_plot{$ab}{$strain}{$i} . ",";
				if($dist_plot{$ab}{$strain}{$i} > $max_ab) {
					$max_ab = $dist_plot{$ab}{$strain}{$i};
				}	
			}	
		}
		if(length($y) > length($strain) + 8) {
			chop $y;
		}
		$y .= ")";
		print R $y . "\n";
	} 
	print R $max_main . "1)\n";
	#Add background
	$y = $tmp_ab . "_background <- c(";
#	for(my $i = (int($longest_seq + $region)/2)* -1; $i < int($longest_seq + $region)/2; $i++) {
	for(my $i = int($longest_seq/2)* -1; $i < int($longest_seq/2); $i++) {
		if(!exists $dist_plot_background{$ab}{$i}) {
			$y .= "0,";
		} else {
			$y .= $dist_plot_background{$ab}{$i} . ",";
		}
	}
	chop $y;
	$y .= ")";
	print R $y . "\n";

	foreach my $motif (keys %dist_plot) {
		$max_second = "max_second <- max(";
		#Skip distance plot for main transcription factor 
		if($motif eq $ab) { next; }
		#	$motif_print = &motif_name($motif);
		$motif_print = analysis::get_motif_name($motif);
		$max = 0;
		$first = 0;
		$strain_number = 1;
		$y = $motif_print . "_background <- c(";
	#	for(my $i = int(($longest_seq + $region)/2) * -1; $i < int(($longest_seq + $region)/2); $i++) {
		for(my $i = int($longest_seq/2) * -1; $i < int($longest_seq/2); $i++) {
			if(!exists $dist_plot_background{$motif}{$i}) {
				$y .= "0,";
			} else {
				$y .= $dist_plot_background{$motif}{$i} . ",";
			}
		}
		chop $y;
		print R $y . ")\n";
		foreach my $strain (keys %{$dist_plot{$motif}}) {
			$y = $motif_print . "_" . $strain . " <- c(";
			$max_second .= $motif_print . "_" . $strain . ",";
			for(my $i = 0; $i < $longest_seq; $i++) {
				if(!exists $dist_plot{$motif}{$strain}{$i}) {
					$y .= "0,";
				} else {
					$y .= $dist_plot{$motif}{$strain}{$i} . ",";
					if($dist_plot{$motif}{$strain}{$i} > $max) {
						$max = $dist_plot{$motif}{$strain}{$i};
					}	
				}	
			}
			chop $y;
			$y .= ")";
			print R $y . "\n";
			#Prepare output for R script
			if($first == 0) {
				#Use plot fo rno motif, because there is no background
				if($no_motif == 0) {
					print R "plot(x, " . $tmp_ab . "_" . $strain . ", type=\"l\", col=\"forestgreen\", main=\"Distance plot for " . $ab . " and " . $motif_print . "\", ylim=c(0, " . $max_ab . "), ylab=\"Motif frequency\")\n";
				}
				$legend_class = "legend_class <- c(\"" . $ab . "_" . $strain. "\",";
				$legend_col = "legend_col <- c(\"forestgreen\",";
				$second_factor{$strain} = "plot(x, " . $motif_print . "_" . $strain . ", col=\"red\", xaxt=\"n\",yaxt=\"n\",xlab=\"\",ylab=\"\", type=\"l\")\n";
				$legend_class .= "\"" . $motif_print . "_" . $strain . "\",";
				$legend_col .= "color[" . $strain_number . "],";
				$first++;
				$strain_number++;
			} else {
				if($no_motif == 0) {
					print R "lines(x, " . $tmp_ab . "_" . $strain . ", col=\"green\")\n";
				}
				$legend_class .= "\"" . $ab . "_" . $strain . "\",";
				$legend_col .= "\"green\",";
			#	print R $second_factor . "\n";
				$second_factor{$strain} =  "lines(x, " . $motif_print . "_" . $strain . ", col=color[" . $strain_number . "])\n";
				$legend_class .= "\"" . $motif_print . "_" . $strain . "\",";
				$legend_col .= "color[" . $strain_number . "],";
				$strain_number++;
			}
		}
		chop $max_second;
		if($no_motif == 0) {
			print R "lines(x, " . "((" . $tmp_ab . "_background/max(" . $tmp_ab . "_background)) * max_main), col=\"black\", lty=3)\n";
		} else {
			print R "plot(x, " . "((" . $tmp_ab . "_background/max(" . $tmp_ab . "_background)) * max_main), col=\"black\", lty=3, type=\"l\", main=\"Distance plot for motif " . $motif_print . "for peaks without " . $ab . "\", ylim=c(0, " . $max_ab . "), ylab=\"Motif frequence\")\n";
		}
		print R $max_second . ")\n";
		print R "par(new=TRUE)\n";
		foreach my $strain (keys %{$dist_plot{$motif}}) {
			print R $second_factor{$strain};
		}
		print R "lines(x, " . "((" . $motif_print . "_background/max(" . $motif_print . "_background))*max_second), col=\"darkgrey\", lty=3)\n";
		print R "axis(4)\n";
		print R $legend_class . "\"" . $ab . " background\", \"" . $motif_print . " background\")\n";
		print R $legend_col . "\"black\", \"darkgrey\")\n";
		print R  "legend(\"topright\", legend_class, col=legend_col, pch=20, bty=\'n\')\n";
	}
	print R "dev.off()\n";
	close R;
	`Rscript $output 2> /dev/null`;	
}

#Generate motif position mutation plots
sub generate_mut_pos_analysis_file{
	$_ = "" for my($mut_freq_sig, $mut_freq_unsig, $y_sig, $y_unsig);
	$_ = 0 for my ($divide, $first, $max, $run, $count, $step);
	my $output = $_[0];
	my %col;
	open R, ">$output";
	#Step one: generate logo sequence for motif
	print R "library(seqLogo)\n";
	print R "library(grid)\n";
	print R "library(gridBase)\n";
	print R "mySeqLogo = seqLogo::seqLogo\n";
	print R "bad = (sapply( body(mySeqLogo), \"==\", \"grid.newpage()\") | sapply( body(mySeqLogo), \"==\", \"par(ask=FALSE)\"))\n";
	print R "body(mySeqLogo)[bad] = NULL\n";
	print R "pdf(\"" . substr($output, 0, length($output) - 2) . ".pdf\", width=10, height=5)\n";
	print R "plot(0, 0, xlim=c(0,0), ylim=c(0,0), main=\"" . $commandline . "\", bty=\'n\', xaxt=\"n\", yaxt=\"n\", col=\"white\", xlab=\"\", ylab=\"\")\n";
	$col{'A'} = "green";
	$col{'C'} = "blue";
	$col{'G'} = "orange";
	$col{'T'} = "red";
	foreach my $motif (sort {$a cmp $b } keys %mut_pos_analysis) {
		$max = 0;
		#Define the max to set y axis
		foreach my $pos (keys %{$mut_pos_analysis{$motif}}) {
			if($pos eq "indel" || $pos eq "multi" || $pos eq "max") { next; }
			foreach my $base (keys %{$mut_pos_analysis{$motif}{$pos}}) {
				if(exists $mut_pos_analysis{$motif}{$pos}{$base}{'N'} && $max < $mut_pos_analysis{$motif}{$pos}{$base}{'N'}) {
					$max = $mut_pos_analysis{$motif}{$pos}{$base}{'N'}
				}
				if(exists $mut_pos_analysis{$motif}{$pos}{$base}{'S'} && $max < $mut_pos_analysis{$motif}{$pos}{$base}{'S'}) {
					$max = $mut_pos_analysis{$motif}{$pos}{$base}{'S'};
				}
			}
		}
		$mut_pos_analysis{$motif}{'max'} = $max; 
		my $A = "A <- c(";
		my $C = "C <- c(";
		my $G = "G <- c(";
		my $T = "T <- c(";
		#Check if PWM is smaller 1 else divide by max for logo
		foreach my $pos (sort {$a <=> $b} keys %{$PWM{$motif}}) {
			if($PWM{$motif}{$pos}{'A'} > 1 || $PWM{$motif}{$pos}{'C'} > 1 || $PWM{$motif}{$pos}{'G'} > 1 || $PWM{$motif}{$pos}{'T'} > 1) {
				$divide = ($PWM{$motif}{$pos}{'A'} + $PWM{$motif}{$pos}{'C'} + $PWM{$motif}{$pos}{'G'} + $PWM{$motif}{$pos}{'T'});
				$A .= "" . ($PWM{$motif}{$pos}{'A'}/$divide) . ",";
				$C .= "" . ($PWM{$motif}{$pos}{'C'}/$divide) . ",";
				$G .= "" . ($PWM{$motif}{$pos}{'G'}/$divide) . ",";
				$T .= "" . ($PWM{$motif}{$pos}{'T'}/$divide) . ",";
			} else {
				$A .= $PWM{$motif}{$pos}{'A'} . ",";
				$C .= $PWM{$motif}{$pos}{'C'} . ",";
				$G .= $PWM{$motif}{$pos}{'G'} . ",";
				$T .= $PWM{$motif}{$pos}{'T'} . ",";
			}
		}
		chop $A;
		chop $C;
		chop $G;
		chop $T;
		$A .= ")";
		$C .= ")";
		$G .= ")";
		$T .= ")";
		$A =~ s/,+\)/\)/g;
		$C =~ s/,+\)/\)/g;
		$G =~ s/,+\)/\)/g;
		$T =~ s/,+\)/\)/g;
		print R $A . "\n";
		print R $C . "\n";
		print R $G . "\n";
		print R $T . "\n";
		print R "pwm = data.frame(A, C, G, T)\n";
		print R "pwm = t(pwm)\n";
		print R "par(mar=c(2.5,2.5,1,1), oma=c(2.5,2.5,1,1))\n";
		$first = 0;
		$step = (1/(keys %{$PWM{$motif}}));
		#Generate the vectors with the number of mutations per position - do it seperately for mutations that change TF binding vs. do not change TF binding
		foreach my $base (keys %col) {
			$count = 0;
			$mut_freq_sig = "mut_freq_sig_" . $base . " <- c(";
			$mut_freq_unsig = "mut_freq_unsig_" . $base . " <- c(";
			$y_sig = "y_sig <- c(";
			$y_unsig = "y_unsig <- c(";
			foreach my $pos (sort {$a <=> $b} keys %{$PWM{$motif}}) {
				if(!exists $mut_pos_analysis{$motif}{$base} || (exists $mut_pos_analysis{$motif}{$base} && !exists $mut_pos_analysis{$motif}{$base}{$pos})) {
					$mut_freq_sig .= "0,";
					$mut_freq_unsig .= "0,";
				} else {
					if(!exists $mut_pos_analysis{$motif}{$base}{$pos}{'S'}) {
						$mut_freq_sig .= "0,";
					} else {
						$mut_freq_sig .= $mut_pos_analysis{$motif}{$base}{$pos}{'S'} . ",";
					}
					if(!exists $mut_pos_analysis{$motif}{$base}{$pos}{'N'}) {
						$mut_freq_unsig .= "0,";
					} else {
						$mut_freq_unsig .= $mut_pos_analysis{$motif}{$base}{$pos}{'N'} . ",";
					}
				}
				if(!exists $mut_pos_analysis{$motif}{'indel'}{'S'}) {
					$mut_pos_analysis{$motif}{'indel'}{'S'} = 0;
				}
				if(!exists $mut_pos_analysis{$motif}{'indel'}{'N'}) {
					$mut_pos_analysis{$motif}{'indel'}{'S'} = 0;
				}
				if($pos > 1) {
					$y_sig .= $pos . " + ($step  * ($pos - 1)) + (0.05 * $count),";
					$y_unsig .= $pos . " + ($step * ($pos - 1)) + 0.2 + (0.05 * $count),";
				} else {
					$y_sig .= $pos . " + (0.05 * $count),";
					$y_unsig .= $pos . " + 0.2 + (0.05 * $count),";

				}
			}
			$count++;
			#Remove last , in case vector was used
			if(length($mut_freq_sig) > 20) {
				chop $mut_freq_sig;
			} else {
				$mut_freq_sig .= "0";
			}
			if(length($mut_freq_unsig) > 22) {
				chop $mut_freq_unsig;
			} else {
				$mut_freq_unsig .= "0";
			}
			chop $y_sig;
			chop $y_unsig;
			$mut_freq_sig .= ")";
			$mut_freq_unsig .= ")";
			$y_sig .= ")";
			$y_unsig .= ")";
			print R $mut_freq_sig . "\n";
			print R $mut_freq_unsig . "\n";
			print R $y_sig . "\n";
			print R $y_unsig . "\n";
			if($first == 0) { 
				print R "plot(y_sig, mut_freq_sig_" . $base . ", xlab=NA, ylim=c(-0.5, " . $mut_pos_analysis{$motif}{'max'} . " * 1.5), axes=FALSE, main=\"" . $motif . "\", col=\"" . $col{$base} . "\", pch=20, xlim=c(0, ". (keys %{$PWM{$motif}}) . "))\n";
				$first++;
			} else {
				print R "points(y_sig, mut_freq_sig_" . $base . ", col=\"" . $col{$base} . "\", pch=20)\n";
			}
			print R "points(y_unsig, mut_freq_unsig_" . $base . ", col=\"" . $col{$base} . "\", pch=8)\n";
			print R "axis(2)\n";
		}
		if(!exists $mut_pos_analysis{$motif}{'indel'}{'S'}) { $mut_pos_analysis{$motif}{'indel'}{'S'} = 0; }
		if(!exists $mut_pos_analysis{$motif}{'indel'}{'N'}) { $mut_pos_analysis{$motif}{'indel'}{'N'} = 0; }
		if(!exists $mut_pos_analysis{$motif}{'multi'}{'S'}) { $mut_pos_analysis{$motif}{'multi'}{'S'} = 0; } 
		if(!exists $mut_pos_analysis{$motif}{'multi'}{'N'}) { $mut_pos_analysis{$motif}{'multi'}{'N'} = 0; }
		print R "legend(\"topleft\", c(\"sig\", \"unsig\", \"A\", \"C\", \"G\", \"T\", \"InDels sig: " . $mut_pos_analysis{$motif}{'indel'}{'S'} . "\", \"Indels not-s: " . $mut_pos_analysis{$motif}{'indel'}{'N'} . "\", \"Multiple SNPs sig: " . $mut_pos_analysis{$motif}{'multi'}{'S'} . "\",\"Multiple SNPs not-s: " . $mut_pos_analysis{$motif}{'multi'}{'N'} . "\"), col=c(\"black\", \"black\", \"" . $col{'A'} . "\", \"" . $col{'C'} . "\", \"" . $col{'G'} . "\", \"" . $col{'T'} . "\", \"black\", \"black\", \"black\", \"black\"), pch=c(20, 8, 16, 16, 16, 16, 16, 16, 16, 16), ncol=4)\n";
		print R "opar <- par(las=1)\n";
		print R "par(opar)\n";	
		print R "mtext(\"Frequencies\", 2, 3)\n";
		print R "vp1 <- viewport(x=0.03, y=0, width=1, height=0.3, just=c(\"left\", \"bottom\"))\n";
		print R "pushViewport(vp1)\n";
		print R "par(new=TRUE, mar=c(2.5,1,1,1.5), oma=c(2.5,1,1,1.5))\n";
		print R "mySeqLogo(pwm, xaxis=FALSE, yaxis=FALSE, ic.scale=FALSE)\n"; 
		print R "popViewport()\n";
		print R "grid.newpage()\n";
		$run++;
	}
	print R "dev.off()\n";
	close R;
	`Rscript $output 2> /dev/null`;
}

#Generate R files
sub generate_R_files {
	$_ = 0 for my($cal_pvalue, $count_obs_one, $count_obs_two, $count_obs_both, $f, $max, $min, $max_delta, $min_delta, $start_pos, $fac, $number_peaks, $width_boxplot, $add_additional, $num_of_muts, $x_count);
	$_ = "" for my($dist_one, $dist_two, $dist_no_mut, $delta_one, $delta_two, $delta_no_mut, $tmp_delta, $filename, $h);
	$_ = () for(%ranked_order, %mut_one, %mut_two);
	if($allele == 1) {
		@strains_working = @strains;
	} else {
		for(my $i = 0; $i < @strains; $i++) {
			for(my $j = 1; $j <= $allele; $j++) {
				push @strains_working, $strains[$i] . "_allele_" . $j;
			}
		}
	}
	my $output_R_file = $_[0];
	my $output_R_file_den = substr($output_R_file, 0, length($output_R_file) - 2) . "_density.R";
	my $output = $_[1];
	my $considered = $_[2];
	open R, ">", $output_R_file;
	open R_DEN, ">", $output_R_file_den;
	#### At some point filter the number of motifs within peak and just report the peaks with one motif
	print R "pdf(\"" . substr($output_R_file, 0, length($output_R_file) - 2) . ".pdf\", width=10, height=5)\n";
	print R "plot(0, 0, xlim=c(0,0), ylim=c(0,0), main=\"" . $commandline . "\", bty=\'n\', xaxt=\"n\", yaxt=\"n\", col=\"white\", xlab=\"\", ylab=\"\")\n";
	print R_DEN "pdf(\"" . substr($output_R_file_den, 0, length($output_R_file_den) - 2) . ".pdf\", width=10, height=5)\n";
	print R_DEN "plot(0, 0, xlim=c(0,0), ylim=c(0,0), main=\"" . $commandline . "\", bty=\'n\', xaxt=\"n\", yaxt=\"n\", col=\"white\", xlab=\"\", ylab=\"\")\n";
	foreach my $motif (sort {$index_motifs{$a} cmp $index_motifs{$b}} keys %index_motifs) {
#		print $motif . "\n";
		$filename = $output . "_" . $motif . ".txt";
		$num_of_muts = `wc -l $filename`;
		$delete{$filename} = 1;
		@split = split('\s+', $num_of_muts);
		if($split[0] == 1) {
			if($ab ne "") {
				print STDERR "No occurrences of " . $motif . " with variants found close to " . $ab . " - No statistical analysis possible\n";
			} else {
				print STDERR "No occurrences of " . $motif . " with variants found within 200bp of peak center - No statistical analysis possible!\n";
			}
			next;
		}
		#Generate motif mutation distribution plots for every motif that occurs close to the chipped motif
		open FH, "<$filename" or die "Can't find $filename: $!\n";
		print R "par(oma=c(0,0,0,0))\n";
		print R_DEN "par(oma=c(0,0,0,0))\n";
		$f = 0;
		$_ = () for (%ranked_order, %mut_one, %mut_two);
		$_ = 0 for ($min, $max, $max_delta, $min_delta, $start_pos, $fac);
		foreach my $line (<FH>) {
			if($f == 0) {
				$h = $line;
				$f++;
				next;
			}
			chomp $line;
			@split = split('\t', $line);
			for(my $i = 0; $i < @strains_working - 1; $i++) {
				for(my $j = $i + 1; $j < @strains_working; $j++) {
					#Save the foldchange between the strains
					#Rank order the peaks according to binding strenght to give the plot the sigmodial shape

					$ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$split[1]} = $split[1 + @strains_working + $i + $j]; 
					if($split[1 + @strains_working + $i + $j] > $max) {
						$max = $split[1 + @strains_working + $i + $j];
					}
					if($split[1 + @strains_working + $i + $j] < $min) {
						$min = $split[1 + @strains_working + $i + $j];
					}
					$fac = &fakrek(@strains_working - 1); 
					$start_pos = (2 + (@strains_working * 2) + $fac);
					#Save all peaks that have mutation in strain one or strain two
				#	if(($split[$start_pos + $i] > 0 && $split[$start_pos + $j] == 0) {
					if($split[$start_pos + $i] > 0 && ($split[$start_pos + $j] != $split[$start_pos + $i])) {
						$mut_one{$strains_working[$i] . "_" . $strains_working[$j]}{$split[1]} = 1;
					}
				#	if($split[$start_pos + $j] > 0 && $split[$start_pos + $i] == 0) {
					if($split[$start_pos + $j] > 0 && ($split[$start_pos + $i] != $split[$start_pos + $j])) {
						$mut_two{$strains_working[$i] . "_" . $strains_working[$j]}{$split[1]} = 1;
					}
					$start_pos = (2 + @strains_working + $fac);
					#Define the delte score (min/max for y axis definition)
					$delta_score{$strains_working[$i] . "_" . $strains_working[$j]}{$split[1]} = $split[$start_pos + $i] - $split[$start_pos + $j];
					if($delta_score{$strains[$i] . "_" . $strains_working[$j]}{$split[1]} > $max_delta) {
						$max_delta = $delta_score{$strains_working[$i] . "_" . $strains_working[$j]}{$split[1]};
					}
					if($delta_score{$strains_working[$i] . "_" . $strains_working[$j]}{$split[1]} < $min_delta) {
						$min_delta = $delta_score{$strains_working[$i] . "_" . $strains_working[$j]}{$split[1]};
					}
				}
			}
		}
		for(my $i = 0; $i < @strains_working - 1; $i++) {
			for(my $j = $i + 1; $j < @strains_working; $j++) {
				$dist_one = "one <- c(";
				$dist_two = "two <- c(";
				$dist_no_mut = "no_mut <- c(";
				$delta_one = "delta_one <- c(";
				$delta_two = "delta_two <- c(";
				$delta_no_mut = "delta_no_mut <- c(";
				$x_count = 1;
				if($delta == 1) {
					$max = $max + $max_delta;
					$min = $min + $min_delta;
				}
				$cal_pvalue = 0;
				#Add some space on the right for the barplots
				$add_additional =  ((keys %{$ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}}) * 0.25);
				if($add_additional < 20) { $add_additional = 20; }
				$width_boxplot = $add_additional;
				if($add_additional < 31) { $width_boxplot = 45; }
				$number_peaks = (keys %{$ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}});
				#Make ticks bigger because scale is bigger
				if($delta_tag == 1) {
					$delta_tick = ((abs($min) + abs($max))/50);
					$fc_low = abs($delta_threshold) * (-1);
					$fc_high = abs($delta_threshold);
				} else {
					$delta_tick = 0.5;
					$fc_low = (log(1/$fc_significant)/log(2));
					$fc_high = log($fc_significant)/log(2);
				}
				print R "plot(c(0," . ((keys %{$ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}}) + $add_additional) . "), c(" . $min . " - (" . $delta_tick . " * 2), " . $max . " + (" . $delta_tick . " * 2)), col=\"white\", xlab=\"rank-ordered peaks\", ylab=\"FC " . $strains_working[$i] . " vs " . $strains_working[$j] . " (log2)\", main=\"" . $strains_working[$i] . " vs " . $strains_working[$j] . "\\n$motif\")\n"; 
				print R "abline(c(0,0), c(0,0))\n";
				#Sort by fold change value between strains
				foreach my $rank (sort {$ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$a} <=> $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$b}} keys %{$ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}}) {
					#Check if this peak has a mutation in strain one
					if(exists $mut_one{$strains_working[$i] . "_" . $strains_working[$j]}{$rank}) {
						$dist_one .= sprintf("%.2f", $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank}) . ",";
						if($delta == 1) {
							print R "points(" . $x_count . ", " . $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} . ", pch=8, col=\"red\")\n";
						 	print R "segments(" . $x_count . ", " . $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} . ", x1 = " . $x_count . ", y1= " . ($ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} + $delta_score{$strains_working[$i] . "_" . $strains_working[$j]}{$rank}) . ", col=\"red\")\n";
						} else {
							print R "segments(" . $x_count . ", " . $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} . " - " . $delta_tick . ", x1 = " . $x_count . ", y1= " . $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} . "+" . $delta_tick . ", col=\"red\")\n";
						}
						#Create output file for motif mutations that follow or do not follow tag counts
						if(exists $tf_for_direction{$motif}) {
							if($ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} < $fc_low) {
								$right_direction{$motif}{$rank} = 1;
							} elsif($fc_low < $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} && $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} < $fc_high) {
								$middle_direction{$motif}{$rank} = 1;
							} else {
								$wrong_direction{$motif}{$rank} = 1;
							}
						}

					}
					#Check if this peak has a mutation in strain two
					if(exists $mut_two{$strains_working[$i] . "_" . $strains_working[$j]}{$rank}) {
						$dist_two .= sprintf("%.2f", $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank}) . ",";
						if($delta == 1) {
							print R "points(" . $x_count . ", " . $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} . ", pch=8, col=\"blue\")\n";
							print R "segments(" . $x_count . " + 0.1, " . $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} . ", x1 = " . $x_count . " + 0.1" . ", y1= " . ($ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} + $delta_score{$strains_working[$i] . "_" . $strains_working[$j]}{$rank}) . ", col=\"blue\")\n";
						} else {
							print R "segments(" . $x_count . " + 0.1, " . $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} . ", x1 = " . $x_count . " + 0.1" . ", y1= " . $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} . "+ (2*" . $delta_tick . "), col=\"blue\")\n";
						}
						#Create output file for motif mutations that follow or do not follow tag counts
						if(exists $tf_for_direction{$motif}) {
							if($ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} < $fc_low) {
								$wrong_direction{$motif}{$rank} = 1;
							} elsif($fc_low < $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} && $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} < $fc_high) {
								$middle_direction{$motif}{$rank} = 1;
							} else {
								$right_direction{$motif}{$rank} = 1;
							}
						}

					}
					#If this peak does not have a mutation add it to the dist_no_mut vector, which will be used to plot the background distribution
					if(!exists $mut_one{$strains_working[$i] . "_" . $strains_working[$j]}{$rank} && !exists $mut_two{$strains_working[$i] . "_" . $strains_working[$j]}{$rank}) {
						$dist_no_mut .= sprintf("%.2f", $ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}{$rank}) . ",";
					}
					$x_count++;	
				}
				#Remove the last comma from the vectors
				if(length($dist_one) > 10) {
					chop $dist_one;
				}
				if(length($dist_two) > 10) {
					chop $dist_two;
				}
				if(length($dist_no_mut) > 15) {
					chop $dist_no_mut;
				}
				$dist_one .= ")";
				$dist_two .= ")";
				$dist_no_mut .= ")";
				#Count number of peaks wiht mutations in strain 1, strain 2 and the number of peaks with this motif in genreal
				$count_obs_one = () = $dist_one =~ /\,/gi;
				$count_obs_two = () = $dist_two =~ /\,/gi;
				$count_obs_both = () = $dist_no_mut =~ /\,/gi;
				#Check that there are "enough" peaks with mutations to calculate a p-value (threshold is set to 4 - should probably be changed to a higher value to filter out all instances where we don't have a big enough sample size to do meaningful statistcs on it)
				if($count_obs_one >= 4 && $count_obs_two >= 4 && $count_obs_both >= 4) {
					$cal_pvalue = 1;
				}
				print R $dist_one . "\n";
				print R $dist_two . "\n";
				print R $dist_no_mut . "\n";
				#Print the legends
				print R "legend(\"topleft\", c(paste(\"" . $strains_working[$i] . ": \", length(one), \" muts\", sep=\"\"), paste(\"" . $strains_working[$j] . ": \", length(two), \" muts\", sep=\"\")), col=c(\"red\", \"blue\", \"white\"), pch=c(16, 16), bty=\'n\')\n";
				print R "legend(\"bottomleft\", \"peaks: " . (keys %{$ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}}) . " with " . $motif . "/" . $considered . " total (" . sprintf("%.2f", ((keys %{$ranked_order{$strains_working[$i] . "_" . $strains_working[$j]}})/$considered) * 100) . "%)\", bty=\'n\')\n";
				#Add the barplots for the t-tests and calculate the p-values for the comparisons of the curves
				if($cal_pvalue == 1) {
					print R "boxplot(c(no_mut), c(one), c(two), boxwex=" . (int($width_boxplot/3) - 10) . ", add=TRUE, at=c(" . ($number_peaks + int($add_additional/3)) . "," . ($number_peaks + (int($add_additional/3) * 2)) . "," . ($number_peaks + (int($add_additional/3) * 3)) . "), col=c(\"grey\", \"red\", \"blue\"), outline=FALSE, axes=FALSE)\n";
					if($no_correction == 1) {
						print R "p_one <- (t.test(no_mut, one)\$p.value\n";
						print R "p_two <- t.test(no_mut, two)\$p.value\n";
						print R "p_both <- t.test(one, two)\$p.value\n";
					} else {
						print R "p_one <- (t.test(no_mut, one)\$p.value) * " . (keys %index_motifs) . "\n";
						print R "p_two <- (t.test(no_mut, two)\$p.value) * " . (keys %index_motifs) . "\n";
						print R "p_both <- (t.test(one, two)\$p.value) * " . (keys %index_motifs) . "\n";
					}
					print R "legend(\"bottomright\", c(\"p-values: \", paste(\"" . $strains_working[$i] . " vs bg: \", round(p_one, digits=6), sep=\"\"), paste(\"" . $strains_working[$j] . " vs bg: \", round(p_two, digits=6), sep=\"\"), paste(\"" . $strains_working[$i] . " vs " . $strains_working[$j] . ": \", round(p_both, digits=6), sep=\"\")), text.col=c(\"black\", \"red\", \"blue\", \"purple\"), cex=0.8, bty=\'n\')\n"; 
				}
				
				#Kernel density plots
				@split_one = split(",", $dist_one);
				@split_two = split(",", $dist_two);
				if(@split_one > 1 && @split_two > 1) {
					print R_DEN $dist_one . "\n";
					print R_DEN $dist_two . "\n";
					print R_DEN $dist_no_mut . "\n";
					print R_DEN "kde_all <- density(no_mut)\n";
					print R_DEN "kde_one <- density(one)\n";
					print R_DEN "kde_two <- density(two)\n";
					print R_DEN "y_max <- max(kde_all\$y, kde_one\$y, kde_two\$y)\n";
					print R_DEN "ks_all_one <- ks.test(no_mut, one)\n";
					print R_DEN "ks_all_two <- ks.test(no_mut, two)\n";
					print R_DEN "ks_one_two <- ks.test(one, two)\n";
					print R_DEN "plot(kde_all, col=\"black\", lwd=4, main=\"" . $strains_working[$i] . " vs " . $strains_working[$j] . "\\n$motif\", ylim=c(0, y_max))\n";
					print R_DEN "lines(kde_one, col=\"red\", lwd=4)\n";
					print R_DEN "lines(kde_two, col=\"blue\", lwd=4)\n";
					print R_DEN "legend(\"topleft\", c(\"background\", \"" . $strains_working[$i] . "\", \"" . $strains_working[$j] . "\"), col=c(\"black\", \"red\", \"blue\"), lty=1, lwd=4, bty=\'n\', cex=0.8)\n";
					if($no_correction == 1) { 
						print R_DEN "legend(\"topright\", c(\"p-values: \", paste(\"" . $strains_working[$i] . " vs bg: \", round(ks_all_one\$p.value, digits=6), sep=\"\"), paste(\"" . $strains_working[$j] . " vs bg: \", round(ks_all_two\$p.value, digits=6), sep=\"\"), paste(\"" . $strains_working[$i] . " vs " . $strains_working[$j] . ": \", round(ks_one_two\$p.value, digits=6), sep=\"\")), text.col=c(\"black\", \"red\", \"blue\", \"purple\"), cex=0.8, bty=\'n\')\n";
					} else {
						print R_DEN "legend(\"topright\", c(\"p-values: \", paste(\"" . $strains_working[$i] . " vs bg: \", round((ks_all_one\$p.value) * " . (keys %index_motifs) . ", digits=6), sep=\"\"), paste(\"" . $strains_working[$j] . " vs bg: \", round((ks_all_two\$p.value) * " . (keys %index_motifs) . ", digits=6), sep=\"\"), paste(\"" . $strains_working[$i] . " vs " . $strains_working[$j] . ": \", round((ks_one_two\$p.value) * " . (keys %index_motifs) . ", digits=6), sep=\"\")), text.col=c(\"black\", \"red\", \"blue\", \"purple\"), cex=0.8, bty=\'n\')\n";
					}
				}
			}
		} 
	}
	#Create the output files in case the user would like to have a list of all motifs that follow the foldchange or do not follow it
	if(keys %tf_for_direction > 0) {
		if(keys %right_direction < 1) {
			print STDERR "No mutations found for all TF that has mutation and changes binding pattern\n";
		}
		if(keys %middle_direction < 1) {
			print STDERR "No mutation found in TF binding motif where foldchange is not significantly different\n";
		}
		if(keys %wrong_direction < 1) {
			print STDERR "No mutation found where TF binding motif score and binding score are going in opposite directions\n";
		}
	}
	foreach my $motif (keys %tf_for_direction) {
		my $f = $tf_dir_name . "same_direction_" . $output . "_" . $motif . ".txt";
		if(-e $f) { `rm $f`; }
		$f = $tf_dir_name . "direction_between_foldchange_" . $output . "_" . $motif . ".txt";
		if(-e $f) { `rm $f`; }
		$f = $tf_dir_name . "opposite_direction_" . $output . "_"  . $motif . ".txt";
		if(-e $f) { `rm $f`; }
	}
	my $count = 1;
	foreach my $motif (keys %right_direction) {
		my $f_name = $tf_dir_name . "same_direction_" . $output . "_" . $motif . ".txt";
		open OUT, ">$f_name" or die "Can't open $f: $!";
		foreach my $pos (keys %{$right_direction{$motif}}) {
			$pos =~ s/_/\t/g;
			print OUT "pos_" . $count . "\t" . $pos . "\t+\n";
			$count++;
		}
		close OUT;
	}
	$count = 1;
	foreach my $motif (keys %middle_direction) {
		my $f_name = $tf_dir_name . "direction_between_foldchange_" . $output . "_" . $motif . ".txt";
		open OUT, ">$f_name" or die "Can't open $f: $!";
		foreach my $pos (keys %{$middle_direction{$motif}}) {
			$pos =~ s/_/\t/g;
			print OUT "pos_" . $count . "\t" . $pos . "\t+\n";
			$count++;
		}
		close OUT;
	}
	$count = 1;
	foreach my $motif (keys %wrong_direction) {
		my $f_name = $tf_dir_name . "opposite_direction_" . $output . "_"  . $motif . ".txt";
		open OUT, ">$f_name" or die "Can't open $f: $!";
		foreach my $pos (keys %{$wrong_direction{$motif}}) {
			$pos =~ s/_/\t/g;
			print OUT "pos_" . $count . "\t" . $pos . "\t+\n";
			$count++;
		}
	}
	print R "dev.off()\n";
	print R_DEN "dev.off()\n";
	close R;
	close R_DEN;
	`Rscript $output_R_file 2> /dev/null`;	
	`Rscript $output_R_file_den 2> /dev/null`;	
}

#Generate files for delta
sub generate_delta_files{
	$_ = "" for my($x, $y, $f);
	my $output = $_[0];
	my $output_R = $_[1];
	open R, ">$output_R";
	print R "pdf(\"" . substr($output_R, 0, length($output_R) - 2) . ".pdf\", width=10, height=5)\n";
	print R "plot(0, 0, xlim=c(0,0), ylim=c(0,0), main=\"" . $commandline . "\", bty=\'n\', xaxt=\"n\", yaxt=\"n\", col=\"white\", xlab=\"\", ylab=\"\")\n";
	foreach my $motif (sort {$index_motifs{$a} cmp $index_motifs{$b}} keys %index_motifs) {
		#Make sure there a mutations in this motif
		$x = "x <- c(";
		$y = "y <- c(";
		$filename = $output . "_" . $motif . ".txt";
		open FH, "<$filename" or die "Can't find $filename: $! on generate_delta_files\n";
		$f = 0;
		foreach my $line (<FH>) {
			if($f == 0) { $f++; next;}
			chomp $line;
			@split = split('\t', $line);
			$x .= $split[4] . ",";
			$y .= ($split[5] - $split[6]) . ",";
		}
		if(length($x) > 8) {
			chop $x;
		}
		$x .= ")";
		if(length($y) > 8) {
			chop $y;
		}
		$y .= ")";
		print R $x . "\n";
		print R $y . "\n";
		print R "plot(x, y, main=\"" . $motif . "\ motif diff vs fc\", xlim=c(min(x, y, 0), max(x, y, 1)), ylim=c(min(x, y, 0), max(x, y, 1)), xlab=\"Foldchange " . $strains[0] . " vs " . $strains[1] . "\", ylab=\"motif difference " . $strains[0] . " vs " . $strains[1] . "\", pch=20)\n";
		print R "abline(c(0,0), c(1,1))\n";
			
	}
	print R "dev.off()\n";
	close R;
	`Rscript $output_R 2> /dev/null`;
}

#Method to center the peaks directly over the motif
sub center_peaks{
	my $peak_center;
	my $dist_to_center;
	my $closest_motif;
	my $start;
	my $tmp_header;
	my $length;
	if($ab eq "") {
		print STDERR "Not possible to center peak - no transcription factor is specified\n";
		print STDERR "Skipping...\n";
	} else {
		#Write PWM of motif to center in file so we can scan 
		open TMP_MOTIF, ">tmp_scan_motif_$ab.txt";
		$delete{"tmp_scan_motif_$ab.txt"} = 1;
		print TMP_MOTIF ">consensus\t$ab\t$motif_scan_scores{$ab}\n";
		foreach my $pos (sort {$a <=> $b} keys %{$PWM{$ab}}) {
			print TMP_MOTIF $PWM{$ab}{$pos}{'A'} . "\t" . $PWM{$ab}{$pos}{'C'} . "\t" . $PWM{$ab}{$pos}{'G'} . "\t" . $PWM{$ab}{$pos}{'T'} . "\n";
		}
		close TMP_MOTIF;
	}
	my $command = "homer2 find -i " . $tmp_out . " -m tmp_scan_motif_" . $ab . ".txt -offset 0 > output_tmp.txt";
	print STDERR $command. "\n";
	`$command`;
	open FH, "<output_tmp.txt";
	#Summarize and merge the peaks between the strains, so we know their exact position within the peak
	my ($block_ref) = analysis::analyze_motifs("output_tmp.txt", \@strains, \%tree, \%lookup_strain, \%last_strain, $allele, $region);
	%block = %$block_ref;
	($block_ref) = analysis::merge_block(\%block, $overlap, \@strains, $seq, \%tree, \%lookup_strain, \%last_strain, $allele);
	%block = %$block_ref;
	$tmp_center = "tmp" . rand();
	open OUT, ">$tmp_center.far_motif";
	$delete{$tmp_center . ".far_motif"} = 1;
	foreach my $position (keys %block) {
		$peak_center = 10000;
		foreach my $motif (keys %{$block{$position}}) {
			foreach my $pos (keys %{$block{$position}{$motif}}) {	
				for(my $i = 0; $i < @strains; $i++) {
					for(my $al = 1; $al <= $allele; $al++) {
						$dist_to_center = int(length($seq->{$position . "_" . $strains[$i] . "_" . $al})/2 - ($pos + ($block{$position}{$motif}{$pos}{'length'}/2)));
						if(abs($dist_to_center) < abs($peak_center)) {
							$peak_center = $dist_to_center;
							$closest_motif = $pos;
						}
					}
				}
			}
		}	
		#Split them up in no motif at all, far motif, or motif in middle and center
		#Save peaks that have the motif withing +/2 center_dist of the peak center - change the coordinates so the motif is in the center - we need to get new sequences for these peaks
		if(abs($peak_center) < $center_dist) {
			@header_recenter = split("_", $position);
			my $new_position = "chr" . substr($header_recenter[0], 3) . "_" . ($header_recenter[1] - $peak_center) . "_" . ($header_recenter[2] - $peak_center);
			$peaks{substr($header_recenter[0], 3)}{$header_recenter[1] - $peak_center} = ($header_recenter[2] - $peak_center);
			$peaks_recentered{substr($header_recenter[0], 3)}{$header_recenter[1] - $peak_center} = ($header_recenter[2] - $peak_center);
		#	$tag_counts{$new_position} = $tag_counts{$position};
			$fc{substr($header_recenter[0], 3)}{$header_recenter[1] - $peak_center} = $fc{substr($header_recenter[0], 3)}{$header_recenter[1]};
			$tag_counts{substr($header_recenter[0], 3)}{$header_recenter[1] - $peak_center} = $tag_counts{substr($header_recenter[0], 3)}{$header_recenter[1]};
			#Remove the old peak coordiantes - if the motif was directly in the center don't do anything
			if(abs($peak_center) > 0) {
				delete $peaks{$position};
				delete $fc{substr($header_recenter[0], 3)}{$header_recenter[1]};
				delete $tag_counts{substr($header_recenter[0], 3)}{$header_recenter[1]};
			}
			$num_of_peaks{'motif'}++;
			#Delete these sequences from original seq hash so we have just seq without motif left at the end
			for(my $i = 0; $i < @strains; $i++) {
				for(my $al = 1; $al <= $allele; $al++) {
					delete $seq->{$position . "_" . $strains[$i] . "_" . $al};
				}
			}
		} else {
			#For all peaks where there is a motif but far away from the peak center, write to output file far
			for(my $i = 0; $i < @strains; $i++) {
				for(my $al = 1; $al <= $allele; $al++) {
					print OUT ">" . $position . "_" . $strains[$i] . "_" . $al . "\n";
					print OUT $seq->{$position . "_" . $strains[$i] . "_" . $al} . "\n";
					$seq_far_motif{$position . "_" . $strains[$i] . "_" . $al} = $seq->{$position . "_" . $strains[$i] . "_" . $al};
					if(length($seq_far_motif{$position . "_" . $strains[$i] . "_" . $al}) > $longest_seq_far_motif) {
						$longest_seq_far_motif = length($seq_far_motif{$position . "_" . $strains[$i]. "_" . $al});
					}
					if($i == 0) {
						$num_of_peaks{'far'}++;
					}
					#Delete these sequences from original seq hash so we have just seq without motif left at the end
					delete $seq->{$position . "_" . $strains[$i] . "_" . $al};
				}
			}
		}
	}
	close OUT;
	#Write all sequences without motif (only sequences left in %seq)
	open OUT, ">$tmp_center.no_motif";
	$delete{$tmp_center . ".no_motif"} = 1;
	foreach my $position (keys %{$seq}) {
		print OUT ">" . $position . "\n";
		print OUT $seq->{$position} . "\n";
		$seq_no_motif{$position} = $seq->{$position};
		if(length($seq_no_motif{$position}) > $longest_seq_no_motif) {
			$longest_seq_no_motif = length($seq_no_motif{$position});
		}
		$num_of_peaks{'no'}++;
		delete $seq->{$position};
	}
	close OUT;
	#For sequences with a motif close to their center - get new sequences with motif exactly in the center
	my ($seq_ref, $l_seq) = analysis::get_seq_for_peaks($tmp_out . ".recenter", \%peaks_recentered, \@strains, $genome_dir, $allele, $line_number, $mut_only, $region, \%tree, \%lookup_strain, \%last_strain);
	$delete{$tmp_out . ".recenter"} = 1;
	%seq_recentered = %{$seq_ref};
	$longest_seq_motif = $l_seq;
	#Write sequences to files 
	$delete{$tmp_center . ".recentered_motif"} = 1;
	open OUT, ">$tmp_center.recentered_motif";
	foreach my $header (keys %seq_recentered) {
		print OUT ">" . $header . "\n";
		print OUT $seq_recentered{$header} . "\n";
	}
	close OUT;
}

#calculates factorial of number
sub fakrek{
        my $number = shift;
        return undef if $number < 0;
        return 1 if $number == 0;
        return ($number * &fakrek ($number -1));
}

sub thread_routine{
	my $file_thread = $_[0];
	my $command = "Rscript " . $file_thread . " > output_" . substr($file_thread, 0, length($file_thread) - 2) . ".txt";
	`$command`;
}

sub monitor_processes {
	my $final_number = 0;
	my $lines;
	my @n;
	print STDERR "\n\n";
	while($final_number < (keys %index_motifs)) {
		$lines = `ls $output* 2> error_tmp | wc -l`;
		chomp $lines;
		@n = split('\t', $lines);
		$final_number = $n[0];
		print STDERR "\t\t" . $final_number . " of " . (keys %index_motifs) . " motifs analyzed so far - " . sprintf("%.2f", (($final_number/(keys %index_motifs))*100)) . "%" . "\r";
	}	
}
