#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use utf8;
use File::Find;
use File::Basename qw(basename);
use feature qw(say);
use Cwd qw(getcwd);
use Carp qw(croak);
use DateTime;
use constant SCALAR => ref \$0;
use constant ARRAY  => ref [];
use constant HASH   => ref {};


our $VERSION = '1.03';
our $LAST    = '2019-10-27';
our $FIRST   = '2018-08-15';


#----------------------------------My::Toolset----------------------------------
sub show_front_matter {
    # """Display the front matter."""

    my $prog_info_href = shift;
    my $sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg of [$sub_name] must be a hash ref!"
        unless ref $prog_info_href eq HASH;

    # Subroutine optional arguments
    my(
        $is_prog,
        $is_auth,
        $is_usage,
        $is_timestamp,
        $is_no_trailing_blkline,
        $is_no_newline,
        $is_copy,
    );
    my $lead_symb = '';
    foreach (@_) {
        $is_prog                = 1  if /prog/i;
        $is_auth                = 1  if /auth/i;
        $is_usage               = 1  if /usage/i;
        $is_timestamp           = 1  if /timestamp/i;
        $is_no_trailing_blkline = 1  if /no_trailing_blkline/i;
        $is_no_newline          = 1  if /no_newline/i;
        $is_copy                = 1  if /copy/i;
        # A single non-alphanumeric character
        $lead_symb              = $_ if /^[^a-zA-Z0-9]$/;
    }
    my $newline = $is_no_newline ? "" : "\n";

    #
    # Fill in the front matter array.
    #
    my @fm;
    my $k = 0;
    my $border_len = $lead_symb ? 69 : 70;
    my %borders = (
        '+' => $lead_symb.('+' x $border_len).$newline,
        '*' => $lead_symb.('*' x $border_len).$newline,
    );

    # Top rule
    if ($is_prog or $is_auth) {
        $fm[$k++] = $borders{'+'};
    }

    # Program info, except the usage
    if ($is_prog) {
        $fm[$k++] = sprintf(
            "%s%s - %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{titl},
            $prog_info_href->{expl},
            $newline,
        );
        $fm[$k++] = sprintf(
            "%s%s v%s (%s)%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{titl},
            $prog_info_href->{vers},
            $prog_info_href->{date_last},
            $newline,
        );
        $fm[$k++] = sprintf(
            "%sPerl %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $^V,
            $newline,
        );
    }

    # Timestamp
    if ($is_timestamp) {
        my %datetimes = construct_timestamps('-');
        $fm[$k++] = sprintf(
            "%sCurrent time: %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $datetimes{ymdhms},
            $newline,
        );
    }

    # Author info
    if ($is_auth) {
        $fm[$k++] = $lead_symb.$newline if $is_prog;
        $fm[$k++] = sprintf(
            "%s%s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{auth}{$_},
            $newline,
        ) for (
            'name',
#            'posi',
#            'affi',
            'mail',
        );
    }

    # Bottom rule
    if ($is_prog or $is_auth) {
        $fm[$k++] = $borders{'+'};
    }

    # Program usage: Leading symbols are not used.
    if ($is_usage) {
        $fm[$k++] = $newline if $is_prog or $is_auth;
        $fm[$k++] = $prog_info_href->{usage};
    }

    # Feed a blank line at the end of the front matter.
    if (not $is_no_trailing_blkline) {
        $fm[$k++] = $newline;
    }

    #
    # Print the front matter.
    #
    if ($is_copy) {
        return @fm;
    }
    else {
        print for @fm;
        return;
    }
}


sub validate_argv {
    # """Validate @ARGV against %cmd_opts."""

    my $argv_aref     = shift;
    my $cmd_opts_href = shift;
    my $sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg of [$sub_name] must be an array ref!"
        unless ref $argv_aref eq ARRAY;
    croak "The 2nd arg of [$sub_name] must be a hash ref!"
        unless ref $cmd_opts_href eq HASH;

    # For yn prompts
    my $the_prog = (caller(0))[1];
    my $yn;
    my $yn_msg = "    | Want to see the usage of $the_prog? [y/n]> ";

    #
    # Terminate the program if the number of required arguments passed
    # is not sufficient.
    #
    my $argv_req_num = shift; # (OPTIONAL) Number of required args
    if (defined $argv_req_num) {
        my $argv_req_num_passed = grep $_ !~ /-/, @$argv_aref;
        if ($argv_req_num_passed < $argv_req_num) {
            printf(
                "\n    | You have input %s nondash args,".
                " but we need %s nondash args.\n",
                $argv_req_num_passed,
                $argv_req_num,
            );
            print $yn_msg;
            while ($yn = <STDIN>) {
                system "perldoc $the_prog" if $yn =~ /\by\b/i;
                exit if $yn =~ /\b[yn]\b/i;
                print $yn_msg;
            }
        }
    }

    #
    # Count the number of correctly passed command-line options.
    #

    # Non-fnames
    my $num_corr_cmd_opts = 0;
    foreach my $arg (@$argv_aref) {
        foreach my $v (values %$cmd_opts_href) {
            if ($arg =~ /$v/i) {
                $num_corr_cmd_opts++;
                next;
            }
        }
    }

    # Fname-likes
    my $num_corr_fnames = 0;
    $num_corr_fnames = grep $_ !~ /^-/, @$argv_aref;
    $num_corr_cmd_opts += $num_corr_fnames;

    # Warn if "no" correct command-line options have been passed.
    if (not $num_corr_cmd_opts) {
        print "\n    | None of the command-line options was correct.\n";
        print $yn_msg;
        while ($yn = <STDIN>) {
            system "perldoc $the_prog" if $yn =~ /\by\b/i;
            exit if $yn =~ /\b[yn]\b/i;
            print $yn_msg;
        }
    }

    return;
}


sub show_elapsed_real_time {
    # """Show the elapsed real time."""

    my @opts = @_ if @_;

    # Parse optional arguments.
    my $is_return_copy = 0;
    my @del; # Garbage can
    foreach (@opts) {
        if (/copy/i) {
            $is_return_copy = 1;
            # Discard the 'copy' string to exclude it from
            # the optional strings that are to be printed.
            push @del, $_;
        }
    }
    my %dels = map { $_ => 1 } @del;
    @opts = grep !$dels{$_}, @opts;

    # Optional strings printing
    print for @opts;

    # Elapsed real time printing
    my $elapsed_real_time = sprintf("Elapsed real time: [%s s]", time - $^T);

    # Return values
    if ($is_return_copy) {
        return $elapsed_real_time;
    }
    else {
        say $elapsed_real_time;
        return;
    }
}


sub pause_shell {
    # """Pause the shell."""

    my $notif = $_[0] ? $_[0] : "Press enter to exit...";

    print $notif;
    while (<STDIN>) { last; }

    return;
}


sub construct_timestamps {
    # """Construct timestamps."""

    # Optional setting for the date component separator
    my $date_sep  = '';

    # Terminate the program if the argument passed
    # is not allowed to be a delimiter.
    my @delims = ('-', '_');
    if ($_[0]) {
        $date_sep = $_[0];
        my $is_correct_delim = grep $date_sep eq $_, @delims;
        croak "The date delimiter must be one of: [".join(', ', @delims)."]"
            unless $is_correct_delim;
    }

    # Construct and return a datetime hash.
    my $dt  = DateTime->now(time_zone => 'local');
    my $ymd = $dt->ymd($date_sep);
    my $hms = $dt->hms($date_sep ? ':' : '');
    (my $hm = $hms) =~ s/[0-9]{2}$//;

    my %datetimes = (
        none   => '', # Used for timestamp suppressing
        ymd    => $ymd,
        hms    => $hms,
        hm     => $hm,
        ymdhms => sprintf("%s%s%s", $ymd, ($date_sep ? ' ' : '_'), $hms),
        ymdhm  => sprintf("%s%s%s", $ymd, ($date_sep ? ' ' : '_'), $hm),
    );

    return %datetimes;
}
#-------------------------------------------------------------------------------


sub parse_argv {
    # """@ARGV parser"""

    my(
        $argv_aref,
        $cmd_opts_href,
        $run_opts_href,
    ) = @_;
    my %cmd_opts = %$cmd_opts_href; # For regexes

    # Parser: Overwrite default run options if requested by the user.
    foreach (@$argv_aref) {
        # Directory of interest
        if (/$cmd_opts{dir}/i) {
            s/$cmd_opts{dir}//;
            $run_opts_href->{dir} = $_;
        }

        # Reporting file
        if (/$cmd_opts{rpt}/i) {
            s/$cmd_opts{rpt}//;
            $run_opts_href->{rpt} = $_;
        }

        # Obtain the size of the directory of interest.
        if (/$cmd_opts{obtain_dir_size}/i) {
            $run_opts_href->{is_obtain_dir_size} = 1;
        }

        # Find and remove empty subdirectories of the directory of interest.
        if (/$cmd_opts{rm_empty_subdirs}/i) {
            $run_opts_href->{is_rm_empty_subdirs} = 1;
        }

        # The front matter won't be displayed at the beginning of the program.
        if (/$cmd_opts{nofm}/) {
            $run_opts_href->{is_nofm} = 1;
        }

        # The shell won't be paused at the end of the program.
        if (/$cmd_opts{nopause}/) {
            $run_opts_href->{is_nopause} = 1;
        }
    }
    # Default reporting file
    if (not $run_opts_href->{rpt}) {
        $run_opts_href->{rpt} =
            (split /\/|\\/, $run_opts_href->{dir})[-1].'_size.txt';
    }

    return;
}


sub obtain_dir_size {
    # """Obtain the size of the directory of interest in byte."""

    my(
        $prog_info_href,
        $run_opts_href,
    ) = @_;
    my $dir = $run_opts_href->{dir};
    my $rpt = $run_opts_href->{rpt};

    my %sizes = (
        b  => 0,
        kb => 0,
        mb => 0,
        gb => 0,
    );

    # Notification
    if (not -e $dir) {
        say "Directory [$dir] not found.";
        return;
    }

    # Calculate directory size in several byte units.
    find(sub { $sizes{b} += -s if -f }, $dir);
    $sizes{kb} = $sizes{b}  / 2**10;
    $sizes{mb} = $sizes{kb} / 2**10;
    $sizes{gb} = $sizes{mb} / 2**10;

    # Fill in a buffer with the directory sizes.
    my(@strings, $k);
    my $lab = "Total size: ";
    $strings[$k++] = sprintf("Path:      [%s]", $dir);
    $strings[$k++] = sprintf("Directory: [%s]", (split /\/|\\/, $dir)[-1]);
    $strings[$k++] = "";
    $strings[$k++] = "$lab$sizes{b} B";
    $strings[$k++] = sprintf("%s%.2f KB", (' ' x length $lab), $sizes{kb});
    $strings[$k++] = sprintf("%s%.2f MB", (' ' x length $lab), $sizes{mb});
    $strings[$k++] = sprintf("%s%.2f GB", (' ' x length $lab), $sizes{gb});

    # Reporting
    open my $rpt_fh, '>:encoding(UTF-8)', $rpt;
    my %tee_fhs = (
        rpt => $rpt_fh,
        scr => *STDOUT,
    );

    # Front matter
    my @fm = show_front_matter($prog_info_href, 'prog', 'auth', 'copy');
    my %datetimes = construct_timestamps('-');
    print $rpt_fh $_ for @fm;
    print $rpt_fh "Obtained at [$datetimes{ymdhms}]\n\n";

    # Directory sizes
    foreach my $fh (sort values %tee_fhs) {
        say $fh $_ for @strings;
    }
    print $rpt_fh "\n".show_elapsed_real_time('copy')."\n";
    close $rpt_fh;

    # Notification
    print "[$rpt] generated.\n";
    show_elapsed_real_time();

    return;
}


sub rm_empty_subdirs {
    # """Find and remove empty subdirectories of the directory of interest."""

    my $dir = shift;
    my @garbage_can = ();

    # Notification
    if (not -e $dir) {
        say "Directory [$dir] not found.";
        return;
    }
    printf("Collecting empty subdirectories in [%s]...\n", $dir);

    # Collect empty subdirectories of the directory of interest
    # using finddepth(), which navigates directories bottom-up.
    my $num_of_files;
    finddepth(
        sub {
            if (-d) {
                $num_of_files = grep { $_ } glob "$_/*";
                push @garbage_can, $File::Find::name if $num_of_files == 0;
            }
        },
        $dir
    );

    # Ask whether to remove the collected empty subdirectories.
    my $is_first_iter = 1;
    my $notice = "empty subdirector".($garbage_can[1] ? "ies" : "y")." found.";
    if (@garbage_can) {
        print "\n>>> \u$notice <<<\n\n";
        my($yn_msg, $yn);
        my $is_all_y = 0; # Guide the user to (ii).
        foreach (@garbage_can) {
            # (i) All-y hook
            # rmdir and move to the next iteration.
            # No more entering into the STDIN while block.
            if ($is_all_y == 1) {
                rmdir;
                say "[$_] removed.";
                next if $_ ne $garbage_can[-1];
            }

            # (ii) User-input taking
            if ($is_all_y == 0) {
                # Warn that the rmdir cannot be undone.
                if ($is_first_iter == 1) {
                    my $caution = "* Caution: rmdir is not irrevocable! *";
                    say "*" x length $caution;
                    say $caution;
                    say "*" x length $caution;
                    $is_first_iter = 0; # No more execution of this block.
                }

                # STDIN while block
                $yn_msg = "Remove [$_]? (y/n/all-y)> ";
                print $yn_msg;
                while ($yn = <STDIN>) {
                    chomp($yn);
                    # All-y
                    if ($yn =~ /\ball-y\b/i) {
                        say "All remaining empty subdirs will be removed.";
                        rmdir; # Remove the current empty subdir.
                        say "[$_] removed.";
                        $is_all_y = 1; # Escape from the while block.
                        last;
                    }
                    # y
                    elsif ($yn =~ /\by\b/i) {
                        rmdir;
                        last;
                    }
                    # n
                    elsif ($yn =~ /\bn\b/i) {
                        last;
                    }
                    # Wrong input
                    else {
                        print $yn_msg;
                    }
                }
            }
        }
    }

    say "\"NO\" $notice" if not @garbage_can;

    return;
}


sub ffinder {
    # """ffinder main routine"""

    if (@ARGV) {
        my %prog_info = (
            titl       => basename($0, '.pl'),
            expl       => 'Inspect files and directories',
            vers       => $VERSION,
            date_last  => $LAST,
            date_first => $FIRST,
            auth       => {
                name => 'Jaewoong Jang',
#                posi => '',
#                affi => '',
                mail => 'jangj@korea.ac.kr',
            },
        );
        my %cmd_opts = ( # Command-line opts
            dir              => qr/-?-dir\s*=\s*/i,
            rpt              => qr/-?-(?:report|rpt)\s*=\s*/i,
            obtain_dir_size  => qr/-?-s\b/i,
            rm_empty_subdirs => qr/-?-r\b/i,
            nofm             => qr/-?-nofm/i,
            nopause          => qr/-?-nopause/i,
        );
        my %run_opts = ( # Program run opts
            dir                 => getcwd(),
            rpt                 => '', # Default defined in parse_argv()
            is_obtain_dir_size  => 0,
            is_rm_empty_subdirs => 0,
            is_nofm             => 0,
            is_nopause          => 0,
        );

        # ARGV validation and parsing
        validate_argv(\@ARGV, \%cmd_opts);
        parse_argv(\@ARGV, \%cmd_opts, \%run_opts);

        # Notification - beginning
        show_front_matter(\%prog_info, 'prog', 'auth')
            unless $run_opts{is_nofm};

        # Main
        obtain_dir_size(\%prog_info, \%run_opts)
            if $run_opts{is_obtain_dir_size};
        rm_empty_subdirs($run_opts{dir})
            if $run_opts{is_rm_empty_subdirs};

        # Notification - end
        pause_shell()
            unless $run_opts{is_nopause};
    }

    system("perldoc \"$0\"") if not @ARGV;

    return;
}


ffinder();
__END__

=head1 NAME

ffinder - Inspect files and directories

=head1 SYNOPSIS

    perl ffinder.pl [-dir=dname] [-report=fname] [-s] [-r]
                    [-nofm] [-nopause]

=head1 DESCRIPTION

ffinder helps inspecting files and directories utilizing the File::Find module.

=head1 OPTIONS

    -dir=dname (default: current working directory)
        The directory of interest.

    -report=fname (short form: -rpt, default: -dir appended by '_size.txt')
        The name of directory size reporting file.

    -s
        Obtain the size of the directory of interest.

    -r
        Find and remove empty subdirectories of the directory of interest.

    -nofm
        The front matter will not be displayed at the beginning of the program.

    -nopause
        The shell will not be paused at the end of the program.

=head1 EXAMPLES

    perl ffinder.pl -s
    perl ffinder.pl -r
    perl ffinder.pl -dir=./whatnot/ -s
    perl ffinder.pl -dir=../reports/ -r

=head1 REQUIREMENTS

    Perl 5
        File::Finder

=head1 SEE ALSO

L<ffinder on GitHub|https://github.com/jangcom/ffinder>

=head1 AUTHOR

Jaewoong Jang <jangj@korea.ac.kr>

=head1 COPYRIGHT

Copyright (c) 2018-2019 Jaewoong Jang

=head1 LICENSE

This software is available under the MIT license;
the license information is found in 'LICENSE'.

=cut
