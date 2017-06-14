#!/usr/bin/perl

use File::Basename;

my $numvfs_file = "/sys/module/mlx4_core/parameters/num_vfs";
open (my $NUMVFS_FILE, "<", $numvfs_file) || die "Can't find num_vfs parameter in sysfs";


my $probevf_file = "/sys/module/mlx4_core/parameters/probe_vf";
open (my $PROBEVF_FILE, "<", $probevf_file) || die "Can't find probe_vf parameter in sysfs";

my $numvfs = <$NUMVFS_FILE>;
my $probevf = <$PROBEVF_FILE>;
my $iters = 0;

while ($numvfs =~ m/((([[:xdigit:]]{4}:)?[[:xdigit:]]{2}:)[[:xdigit:]]{2}.[[:xdigit:]])-([[:digit:]]+)(;([[:digit:]]+))?(;([[:digit:]]+))?,?/g)
{
	$iters++;
	my $bdf = $1;
	my $first = $4;
	my $second = $6;
	my $third = $8;
	my $p1, $p2, $both;
	if (!defined($second) && !defined($third)) {
		$both = $first;
		$p1 = $p2 = 0;
	} else {
		$p1 = $first;
		$p2 = $second;
		$both = $third;
	}
	my @ports = (["\tPort 1: " . int($p1) . " \n", int($p1), 0],
		     ["\tPort 2: " . int($p2) . " \n", int($p2), int($p1)],
		     ["\tBoth: " . int($both) . " \n", int($both), int($p1) + int($p2)]);

	open(LSPCI, "lspci -D -s $bdf 2>/dev/null |") || next;
	if (!eof(LSPCI)) {
		print "BDF $bdf\n";
		parse_bdf(\@ports, $2, $bdf);
	}
}

if (!$iters) {
	if ($numvfs =~ m/([[:digit:]]+)(,([[:digit:]]+))?(,([[:digit:]]+))?/g) {
		my $first = $1;
		my $second = $3;
		my $third = $5;
		my $p1, $p2, $both;
		if (!defined($second) && !defined($third)) {
			$both = $first;
			$p1 = $p2 = 0;
		} else {
			$p1 = $first;
			$p2 = $second;
			$both = $third;
		}
		my @ports = (["\tPort 1: " . int($p1) . " \n", int($p1), 0],
			     ["\tPort 2: " . int($p2) . " \n", int($p2), int($p1)],
			     ["\tBoth: " . int($both) . " \n", int($both), int($p1) + int($p2)]);
		open(my $LSPCI, "lspci -D | grep Mellanox | grep -v \"Virtual Function\" |") || die "Failed $!\n";
		while (<$LSPCI>) {
			my ($full_bdf) = $_ =~ /(^[^ ]*)/;
			my ($bdf) = $full_bdf =~ /(^(([[:xdigit:]]{4}:)?[[:xdigit:]]{2}:))/;
			print "BDF $full_bdf\n";
			parse_bdf(\@ports, $bdf, $full_bdf);
		}

	} else {
		print "No devices found\n";
	}
}

sub map_bdf_vf {
	my $pf_bdf = $_[0];
	my %hash = ();
	my $sysfs_dir = "/sys/bus/pci/devices/*$pf_bdf";
	my @virt_fns = <$sysfs_dir/virtfn*>;
	foreach (@virt_fns) {
		my ($fn) = fileparse($_) =~ /([0-9]+)$/;
		$fn = "vf$fn";
		my $link = readlink($_);
		my ($bdf) = $link =~ /(([:.]*[[:xdigit:]])+)/;
		$link = "$sysfs_dir/" . $link;
		$hash{$bdf} = $fn;
	}
	return %hash;
}

sub parse_bdf {
	my ($ports_ref, $bdf, $full_bdf) = @_;
	my @ports = @$ports_ref;
	my $counter = 0;
	my $ports_index = 0;
	my %hash = map_bdf_vf($full_bdf);
	open(my $LSPCI, "lspci -D -s $bdf | tail -n +2 |") || die "Failed $!\n";
	while (<$LSPCI>) {
		while ($counter == $ports[$ports_index]->[1] + $ports[$ports_index]->[2]) {
			print $ports[$ports_index]->[0];
			$ports_index++;
		}

		if ($counter == $ports[$ports_index]->[2]) {
			print $ports[$ports_index]->[0];
		}
		my ($vf_bdf) = $_ =~ /(^[^ ]*)/;
		print "\t\t$hash{\"$vf_bdf\"}\t$vf_bdf\n";
		$counter++;
	}
	while ($ports_index++ < $#ports) {
		print $ports[$ports_index]->[0];
	}
}


