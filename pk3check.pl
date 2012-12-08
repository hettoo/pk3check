#!/usr/bin/perl

use strict;
use warnings;

use autodie;
use Getopt::Long;
use File::Find;
use File::Copy;
use Digest::MD5 'md5';

use Archive::Zip;

my $install_dir = '/opt/warsow/';
my $personal_dir = $ENV{'HOME'} . '/.warsow-1.0/';
my $coremod = 'basewsw';
my $pure_only;
my $packed_only;
my $strip;
my $delete;
my $full_delete;
my $rename_suffix = '_fix';
my $backup;
my $specific_mod;

GetOptions(
    "install-dir=s" => \$install_dir,
    "personal-dir=s" => \$personal_dir,
    "coremod=s" => \$coremod,
    "pure-only" => \$pure_only,
    "packed-only" => \$packed_only,
    "strip" => \$strip,
    "delete" => \$delete,
    "full-delete" => \$full_delete,
    "rename-suffix=s" => \$rename_suffix,
    "backup=s" => \$backup,
    "mod=s" => \$specific_mod
) or exit 1;

$install_dir =~ s/([^\/])$/$1\//;
$personal_dir =~ s/([^\/])$/$1\//;

my $dir;
my $files;
my %renamed;

my $original;
my $original_dir = $install_dir . $coremod . '/';

$dir = $original_dir;
clean();
analyze();
remove_duplicates();
$original = $files;
undef $pure_only;
undef $packed_only;
$dir = $personal_dir . $coremod . '/';
my @mods;
if (defined $specific_mod) {
    @mods = ($specific_mod);
} else {
    @mods = subdirs($personal_dir);
}
for my $mod(@mods) {
    $dir = $personal_dir . $mod . '/';
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
}

sub remove_duplicates {
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
            if (!$pure_only || $file =~ /pure\.[^\.]*$/) {
                analyze_pk3($file);
            }
        } elsif (!$pure_only && !$packed_only) {
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
                            print "$file from $dir$pk3 overwrites the one from $original_dir$original_pk3\n";
                            modify($dir . $pk3, $file);
                            next FILE;
                        }
                    }
                }
            }
        }
    }
}

sub modify {
    my($base, $file) = @_;
    if (is_pak($base)) {
        if ($strip) {
            my $zip = Archive::Zip->new();
            my $is_renamed = defined $renamed{$base};
            if ($is_renamed) {
                $base = $renamed{$base};
            }
            $zip->read($base);
            $zip->removeMember($file);
            if ($is_renamed) {
                $zip->overwrite();
            } else {
                my $new_name = $base;
                $new_name =~ s/(\.[^\.]*)$/$rename_suffix$1/;
                $zip->overwriteAs($new_name);
                if (defined $backup) {
                    move($base, $base . $backup);
                } else {
                    unlink $base;
                }
                $renamed{$base} = $new_name;
            }
        } elsif ($full_delete) {
            if (defined $backup) {
                move($base, $base . $backup);
            } else {
                unlink $base;
            }
        }
    } elsif ($delete || $full_delete) {
        if (defined $backup) {
            move($base . $file, $base . $file . $backup);
        } else {
            unlink $base . $file;
        }
    }
}
