#!/usr/bin/evn perl
use strict;
use warnings;
use Getopt::Long;
use Storable;
use Set::IntervalTree;
use config;
use general;
use analysis_tree;
use Data::Dumper;

$_ = "" for my($output, $data_dir, $genome_dir, $strain, $allele, $chr);
$_ = () for my(%peaks, %strand, @split, %tree, %last_strain, @tmp_split, %save_id, $tree, @files, $tree_tmp, @strains, %last, $last, @chr_split, $tree_tmp_1, $tree_tmp_2, %tree_detail, $tree_detail, $tree_tmp_detail_1, $tree_tmp_detail_2);
$_ = 0 for my($hetero, $line_number, $id);

sub printCMD {
        print STDERR "Usage:\n";
        print STDERR "\t-ind <individual>: Individual we look for muts versus reference\n";
	print STDERR "\t-inds <individuals>: Two individuals we look for muts against each otehr\n";
        print STDERR "\t-files <files>: Comma seperated list of files\n";
	print STDERR "\t-data_dir <path to individual mutation data>: default defined in config\n";
	print STDERR "\t-genome_dir <path to individual genomes>: default defined in config\n";
	print STDERR "\t-hetero: Data is heterozygous\n";
        exit;
}

if(@ARGV < 1) {
        &printCMD();
}

my %mandatory = ('-files' => 1);
my %convert = map { $_ => 1 } @ARGV;
config::check_parameters(\%mandatory, \%convert);


GetOptions(   	"files=s{,}" => \@files,
		"ind=s" => \$strain,
		"inds=s{,}" => \@strains,
		"genome_dir=s" => \$genome_dir,
		"data_dir=s" => \$data_dir,
		"hetero" => \$hetero)
	or die(&printCMD());
#First step: Get the sequences for the peaks

#Set variables
if($data_dir eq "") {
	$data_dir = config::read_config()->{'data_folder'};
}
if($genome_dir eq "") {
	$genome_dir = $data_dir;
}
if($strain eq "" && @strains < 1) {
	&printCMD();
}

if($strain ne "") {
	$strain = uc($strain);
}

if(@strains == 1) {
	my @a = split(",", $strains[0]);
	for(my $i = 0; $i < @a; $i++) {
		$a[$i] =~ s/,//g;
		$strains[$i] = uc($a[$i]);
	}
} elsif(@strains > 1) {
	for(my $i = 0; $i < @strains; $i++) {
		$strains[$i] =~ s/,//g;
		$strains[$i] = uc($strains[$i]);
	}
}

for(my $i = 0; $i < @files; $i++) {
	$files[$i] =~ s/,//g;
}
print STDERR "Read in mutations\n";
if(@strains < 1) {
	($tree, $tree_detail, $last) = general::read_strains_mut($strain, $data_dir);
} else {
	($tree, $last) = general::read_mutations_from_two_strains($strains[0], $strains[1], $data_dir);
}
my $next = 0;
my $no_mut = 0;
my $all_lines = 0;
my $printed_lines = 0;
print STDERR "Processing sam file\n";
my @name;
my %save;
my @base;

foreach my $file (@files) {
	print STDERR $file . "\n";
	open(my $fh, "<", $file);
#	open FH, "<$file";
	@split = split("/", $file);
	$output = "";
	for(my $i = 0; $i < @split - 1; $i++) {
		$output .= $split[$i] . "/";
	}
	$output .= "only_muts_" . $split[-1];
	open OUT, ">$output";
	$_ = 0 for($next, $no_mut, $all_lines, $printed_lines);
	while(my $line = <$fh>) {
#	foreach my $line (<FH>) {
		$all_lines++;
		chomp $line;
		if(substr($line, 0, 1) eq "@") {
			print OUT $line . "\n";
		} else {
			@split = split('\t', $line);
			@chr_split = split("_", $split[2]);
			$chr = substr($chr_split[0], 3);
			if(!exists $tree->{$chr}) { next; }
			if(@chr_split < 2) {
				$allele = 1;
			} else {
				$allele = $chr_split[2];
			}
			if($split[3] + length($split[9]) > $last->{$chr}->{$allele}->{'pos'}) { $next++; next; }
			if($hetero == 0) {
				$tree_tmp = $tree->{$chr}->{$allele}->fetch($split[3], $split[3] + length($split[9]));
				if(exists $tree_tmp->[0]->{'mut'}) {
					print OUT $line . "\n";
					$printed_lines++;
				} else {
					$no_mut++;
				}
			} else {
				$tree_tmp_1 = $tree->{$chr}->{'1'}->fetch($split[3], $split[3] + length($split[9]));
				$tree_tmp_2 = $tree->{$chr}->{'2'}->fetch($split[3], $split[3] + length($split[9]));
				$tree_tmp_detail_1 = $tree_detail->{$chr}->{'1'}->fetch($split[3], $split[3] + length($split[9]));
				$tree_tmp_detail_2 = $tree_detail->{$chr}->{'2'}->fetch($split[3], $split[3] + length($split[9]));
				if(exists $tree_tmp_1->[0]->{'mut'} && !exists $tree_tmp_2->[0]->{'mut'}) {
					print OUT $line . "\n";
					$printed_lines++;
				} elsif(!exists $tree_tmp_1->[0]->{'mut'} && exists $tree_tmp_2->[0]->{'mut'}) {
					print OUT $line . "\n";
					$printed_lines++;
				} elsif(exists $tree_tmp_1->[0]->{'mut'} && exists $tree_tmp_2->[0]->{'mut'}) {
					if((scalar @{$tree_tmp_1}) != (scalar @{$tree_tmp_2})) {
						print OUT $line . "\n";
						$printed_lines++;
					} else {
						for(my $i = 0; $i < (scalar @{$tree_tmp_1}); $i++) {
							if($tree_tmp_1->[$i]->{'mut'} ne $tree_tmp_2->[$i]->{'mut'}) {
								print OUT $line . "\n";
								$printed_lines++;
								last;
							} else {
								if($tree_tmp_detail_1->[$i]->{'pos'} ne $tree_tmp_detail_2->[$i]->{'pos'}) {
									print OUT $line;
									$printed_lines++;
									last;
							 	}	
							}
						}
					}
				} else {
					$no_mut++;
				}
			}
		}
	}
#	close FH;	
	close $fh;
	close OUT;
	open LOG, ">$output.log";
	print LOG "Get only sequences spanning mutations for $file\n";
	print LOG "All lines looked at:\t\t" . $all_lines. "\n";
	print LOG "All lines spanning mutations:\t" . $printed_lines . "\t(" . ($printed_lines/$all_lines) . ")\n";
	print LOG "All lines not spanning mutations:\t" . $no_mut . "\t(" . ($no_mut/$all_lines) . ")\n";
	print LOG "All lines skipped:\t\t" . $next . "\t(" . ($next/$all_lines) . ")\n";
	close LOG;
}

