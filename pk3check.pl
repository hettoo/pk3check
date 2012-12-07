#!/usr/bin/perl

use strict;
use warnings;

use File::Find;

use Archive::Zip;

my $INSTALL_DIR = '/opt/warsow/';
my $PERSONAL_DIR = $ENV{'HOME'} . '/.warsow-1.0/';
my $BASEMOD = 'basewsw';

my $dir;
my $files;

my $original;
my $original_dir = $INSTALL_DIR . $BASEMOD . '/';

$dir = $original_dir;
clean();
analyze();
$original = $files;
$dir = $PERSONAL_DIR . $BASEMOD . '/';
my @mods = subdirs($PERSONAL_DIR);
for my $mod(@mods) {
    $dir = $PERSONAL_DIR . $mod . '/';
    clean();
    analyze();
    check($files);
}
exit;

sub subdirs {
    my($base) = @_;
    my @dirs;
    my $dir;
    opendir $dir, $base;
    while (my $file = readdir $dir) {
        if (-d "$base/$file" && $file ne '.' && $file ne '..') {
            push @dirs, $file;
        }
    }
    closedir $dir;
    return @dirs;
}

sub clean {
    $files = {
        '' => []
    };
}

sub analyze {
    find(\&encounter_file, $dir);
}

sub encounter_file {
    my $file = $File::Find::name;
    $file =~ s/^$dir//;
    if ($file . '/' ne $dir && !-d $File::Find::name) {
        if ($file =~ /\.(pk3|pak|pk2)$/) {
            analyze_pk3($file);
        } else {
            push @{$files->{''}}, $file;
        }
    }
}

sub analyze_pk3 {
    my($pk3) = @_;
    my $zip = Archive::Zip->new();
    $zip->read($dir . $pk3);
    $files->{$pk3} = [files($zip->memberNames())];
}

sub files {
    my(@total) = @_;
    return grep !/\/$/, @total;
}

sub check {
    my($files) = @_;
    for my $pk3(keys %{$files}) {
        FILE: for my $file(@{$files->{$pk3}}) {
            for my $original_pk3(keys %{$original}) {
                if ($pk3 ne $original_pk3) {
                    for my $original_file(@{$original->{$original_pk3}}) {
                        if ($file eq $original_file) {
                            print "$file from $dir$pk3 overwrites $original_file from $original_dir$original_pk3\n";
                            next FILE;
                        }
                    }
                }
            }
        }
    }
}
