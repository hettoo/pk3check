#!/usr/bin/perl

use strict;
use warnings;

use File::Find;
use Digest::MD5 'md5';

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

sub exists_after {
    my($base, $file) = @_;
    for my $base2(keys %{$files}) {
        my @filtered;
        for my $file2(@{$files->{$base2}}) {
            if ($file eq $file2) {
                return $base ne '' && ($base2 gt $base || $base2 eq '');
            }
        }
    }
    return 0;
}

sub analyze {
    find(\&encounter_file, $dir);
    for my $base(keys %{$files}) {
        my @filtered;
        for my $file(@{$files->{$base}}) {
            if (!exists_after($base, $file)) {
                push @filtered, $file;
            }
        }
        $files->{$base} = \@filtered;
    }
}

sub is_pak {
    my($file) = @_;
    return $file =~ /\.(pk3|pak|pk2)$/;
}

sub encounter_file {
    my $file = $File::Find::name;
    $file =~ s/^$dir//;
    if ($file . '/' ne $dir && !-d $File::Find::name) {
        if (is_pak($file)) {
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

sub read_file {
    my($base, $file) = @_;
    my $result;
    if (is_pak($base)) {
        my $zip = Archive::Zip->new();
        $zip->read($base);
        $result = $zip->contents($file);
    } else {
        my $fh;
        local $/;
        open $fh, '<', $base . $file;
        $result = <$fh>;
        close $fh;
    }
    return $result;
}

sub check {
    my($files) = @_;
    for my $pk3(keys %{$files}) {
        FILE: for my $file(@{$files->{$pk3}}) {
            for my $original_pk3(keys %{$original}) {
                for my $original_file(@{$original->{$original_pk3}}) {
                    if ($file eq $original_file) {
                        if (md5(read_file($dir . $pk3, $file)) ne md5(read_file($original_dir . $original_pk3, $original_file))) {
                            print "$file from $dir$pk3 overwrites $original_file from $original_dir$original_pk3\n";
                            next FILE;
                        }
                    }
                }
            }
        }
    }
}
