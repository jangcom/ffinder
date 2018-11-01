#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use DateTime;
use File::Find;
use File::Basename qw(basename);
use autodie        qw(open close);
use feature        qw(say);
use Cwd            qw(getcwd);
use Carp           qw(croak);
use constant ARRAY => ref [];
use constant HASH  => ref {};


#
# Outermost lexicals
#
my %prog_info = (
    titl        => basename($0, '.pl'),
    expl        => "Files and dirs inspection assistant",
    vers        => "v1.0.0",
    date_last   => "2018-08-23",
    date_first  => "2018-08-15",
    opts        => { # Command-line options
        size    => qr/-s\b/i,
        subdirs => qr/-r\b/i,
    },
    auth        => {
        name => 'Jaewoong Jang',
        posi => 'PhD student',
        affi => 'University of Tokyo',
        mail => 'jang.comsci@gmail.com',
    },
    usage       => <<'    END_HEREDOC'
    NAME
        ffinder - Files and dirs inspection assistant

    SYNOPSIS
        perl ffinder.pl [-s] [-r]

    DESCRIPTION
        This program utilizes the File::Find module of Perl 5
        for inspecting and handling files and directories.

    OPTIONS
        -s
            Obtain the size of the current working directory.
        -r
            Remove empty subdirectories from the current working
            directory in an interactive fashion.

    EXAMPLES
        perl ffinder.pl -s
        perl ffinder.pl -r

    REQUIREMENTS
        Perl 5, Perl File::Finder

    SEE ALSO
        perl(1)

    AUTHOR
        Jaewoong Jang <jang.comsci@gmail.com>

    COPYRIGHT
        Copyright (c) 2018 Jaewoong Jang

    LICENSE
        This software is available under the MIT license;
        the license information is found in 'LICENSE'.
    END_HEREDOC
);
my %sizes = (
    B  => 0,
    KB => 0,
    MB => 0,
    GB => 0,
);
my $two_to_the_tenth = 2**10;
my @garbage_can = ();
my %subs = (
    obtain_cwd_size  => {code_ref => \&obtain_cwd_size,  switch => 'off'},
    rm_empty_subdirs => {code_ref => \&rm_empty_subdirs, switch => 'off'},
);


#
# Subroutine calls
#
if (@ARGV) {
    show_front_matter(\%prog_info, 'prog', 'auth');
    validate_argv(\%prog_info, \@ARGV);
    parse_argv();
}
elsif (not @ARGV) {
    show_front_matter(\%prog_info, 'usage');
}
pause_shell();


#
# Subroutine definitions
#
sub parse_argv {
    my @_argv = @ARGV;
    
    foreach (@_argv) {
        $subs{obtain_cwd_size}{switch}  = 'on' if /$prog_info{opts}{size}/;
        $subs{rm_empty_subdirs}{switch} = 'on' if /$prog_info{opts}{subdirs}/;
    }
    
    $subs{obtain_cwd_size}{code_ref}->()
        if $subs{obtain_cwd_size}{switch} eq 'on';
    $subs{rm_empty_subdirs}{code_ref}->()
        if $subs{rm_empty_subdirs}{switch} eq 'on';
}


sub obtain_cwd_size {
    # Obtain the size of the CWD in byte.
    find(sub { $sizes{B} += -s if -f }, '.');
    
    # Convert the size wrto bigger units.
    $sizes{KB} = $sizes{B}  / $two_to_the_tenth;
    $sizes{MB} = $sizes{KB} / $two_to_the_tenth;
    $sizes{GB} = $sizes{MB} / $two_to_the_tenth;
    
    # Fill in a buffer with the sizes.
    my(@strings, $k);
    my $lab = "Total size: ";
    my %_datetimes = construct_timestamps('-');
    $strings[$k++] = $_datetimes{ymdhms};
    $strings[$k++] = sprintf("Path:      [%s]", getcwd());
    $strings[$k++] = sprintf("Directory: [%s]", (split /\/|\\/, getcwd())[-1]);
    $strings[$k++] = "";
    $strings[$k++] = "$lab$sizes{B} B";
    $strings[$k++] = sprintf("%s%.2f KB", (' ' x length($lab)), $sizes{KB});
    $strings[$k++] = sprintf("%s%.2f MB", (' ' x length($lab)), $sizes{MB});
    $strings[$k++] = sprintf("%s%.2f GB", (' ' x length($lab)), $sizes{GB});
    $strings[$k++] = "";
    $strings[$k++] = show_elapsed_real_time('copy');
    
    # Print the sizes.
    my $rpt_fname = basename($0, '.pl').'_cwd_size.txt';
    open my $rpt_fh, '>:encoding(UTF-8)', $rpt_fname;
    
    say for @strings;
    say $rpt_fh $_ for @strings;
    
    close $rpt_fh;
}


sub rm_empty_subdirs {
    printf("Collecting empty subdirectories from [%s]...\n", getcwd());
    #
    # Collect empty subdirectories of the CWD.
    # Use finddepth(), which navigates directories bottom-up.
    #
    my $num_of_files;
    finddepth(
        sub {
            if (-d) {
                $num_of_files = grep $_, glob "$_/*";
                
                if ($num_of_files == 0) {
                    push @garbage_can, $File::Find::name;
                }
            }
        },
        '.'
    );
    
    #
    # Ask whether to remove the collected empty subdirectories.
    #
    my $is_first_iter = 1;
    my $notice        = "empty subdirectories found.";
    if (@garbage_can) {
        say "\n\u$notice\n";
        my($yn_msg, $yn);
        my $is_all_y = 0; # Make the user enter into (ii).
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
                    my $_caution = "* Caution: rmdir is not irrevocable! *";
                    say "*" x length($_caution);
                    say $_caution;
                    say "*" x length($_caution);
                    $is_first_iter = 0; # No more execution of this block.
                }
                
                # STDIN while block
                $yn_msg = "Remove [$_]? (y/n/all-y)> ";
                print $yn_msg;
                while ($yn = <STDIN>) {
                    chomp($yn);
                    # All-y
                    if ($yn =~ /\ball-y\b/i) {
                        rmdir;
                        say "All remaining empty subdirs will be removed.";
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
        print "No more empty subdirectories. ";
    }
    say "\"NO\" $notice" if not @garbage_can;
}


#
# Subroutines from My::Toolset
#
sub show_front_matter {
    my $hash_ref = shift; # Arg 1: To be %_prog_info
    
    #
    # Data type validation and deref: Arg 1
    #
    my $_sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg to [$_sub_name] must be a hash ref!"
        unless ref $hash_ref eq HASH;
    my %_prog_info = %$hash_ref;
    
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
    my $lead_symb    = '';
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
    my @_fm;
    my $k = 0;
    my $border_len = $lead_symb ? 69 : 70;
    my %borders = (
        '+' => $lead_symb.('+' x $border_len).$newline,
        '*' => $lead_symb.('*' x $border_len).$newline,
    );
    
    # Top rule
    if ($is_prog or $is_auth) {
        $_fm[$k++] = $borders{'+'};
    }
    
    # Program info, except the usage
    if ($is_prog) {
        $_fm[$k++] = sprintf(
            "%s%s %s: %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $_prog_info{titl},
            $_prog_info{vers},
            $_prog_info{expl},
            $newline
        );
        $_fm[$k++] = sprintf(
            "%s%s%s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            'Last update:'.($is_timestamp ? '  ': ' '),
            $_prog_info{date_last},
            $newline
        );
    }
    
    # Timestamp
    if ($is_timestamp) {
        my %_datetimes = construct_timestamps('-');
        $_fm[$k++] = sprintf(
            "%sCurrent time: %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $_datetimes{ymdhms},
            $newline
        );
    }
    
    # Author info
    if ($is_auth) {
        $_fm[$k++] = $lead_symb.$newline if $is_prog;
        $_fm[$k++] = sprintf(
            "%s%s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $_prog_info{auth}{$_},
            $newline
        ) for qw(name posi affi mail);
    }
    
    # Bottom rule
    if ($is_prog or $is_auth) {
        $_fm[$k++] = $borders{'+'};
    }
    
    # Program usage: Leading symbols are not used.
    if ($is_usage) {
        $_fm[$k++] = $newline if $is_prog or $is_auth;
        $_fm[$k++] = $_prog_info{usage};
    }
    
    # Feed a blank line at the end of the front matter.
    if (not $is_no_trailing_blkline) {
        $_fm[$k++] = $newline;
    }
    
    #
    # Print the front matter.
    #
    if ($is_copy) {
        return @_fm;
    }
    elsif (not $is_copy) {
        print for @_fm;
    }
}


sub show_elapsed_real_time {
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
    @opts    = grep !$dels{$_}, @opts;
    
    # Optional strings printing
    print for @opts;
    
    # Elapsed real time printing
    my $elapsed_real_time = sprintf("Elapsed real time: [%s s]", time - $^T);
    
    # Return values
    say    $elapsed_real_time if not $is_return_copy;
    return $elapsed_real_time if     $is_return_copy;
}


sub construct_timestamps {
    # Optional setting for the date component separator
    my $_date_sep  = '';
    
    # Terminate the program if the argument passed
    # is not allowed to be a delimiter.
    my @_delims = ('-', '_');
    if ($_[0]) {
        $_date_sep = $_[0];
        my $is_correct_delim = grep $_date_sep eq $_, @_delims;
        croak "The date delimiter must be one of: [".join(', ', @_delims)."]"
            unless $is_correct_delim;
    }
    
    # Construct and return a datetime hash.
    my $_dt  = DateTime->now(time_zone => 'local');
    my $_ymd = $_dt->ymd($_date_sep);
    my $_hms = $_dt->hms(($_date_sep ? ':' : ''));
    (my $_hm = $_hms) =~ s/[0-9]{2}$//;
    
    my %_datetimes = (
        none   => '', # Used for timestamp suppressing
        ymd    => $_ymd,
        hms    => $_hms,
        hm     => $_hm,
        ymdhms => sprintf("%s%s%s", $_ymd, ($_date_sep ? ' ' : '_'), $_hms),
        ymdhm  => sprintf("%s%s%s", $_ymd, ($_date_sep ? ' ' : '_'), $_hm),
    );
    
    return %_datetimes;
}


sub validate_argv {
    my $hash_ref  = shift; # Arg 1: To be %_prog_info
    my $array_ref = shift; # Arg 2: To be @_argv
    my $num_of_req_argv;   # Arg 3: (Optional) Number of required args
    $num_of_req_argv = shift if defined $_[0];
    
    #
    # Data type validation and deref: Arg 1
    #
    my $_sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg to [$_sub_name] must be a hash ref!"
        unless ref $hash_ref eq HASH;
    my %_prog_info = %$hash_ref;
    
    #
    # Data type validation and deref: Arg 2
    #
    croak "The 2nd arg to [$_sub_name] must be an array ref!"
        unless ref $array_ref eq ARRAY;
    my @_argv = @$array_ref;
    
    #
    # Terminate the program if the number of required arguments passed
    # is not sufficient.
    # (performed only when the 3rd optional argument is given)
    #
    if ($num_of_req_argv) {
        my $num_of_req_argv_passed = grep $_ !~ /-/, @_argv;
        if ($num_of_req_argv_passed < $num_of_req_argv) {
            say $_prog_info{usage};
            say "    | You have input $num_of_req_argv_passed required args,".
                " but we need $num_of_req_argv.";
            say "    | Please refer to the usage above.";
            exit;
        }
    }
    
    #
    # Count the number of correctly passed options.
    #
    
    # Non-fnames
    my $num_of_corr_opts = 0;
    foreach my $arg (@_argv) {
        foreach my $v (values %{$_prog_info{opts}}) {
            if ($arg =~ /$v/i) {
                $num_of_corr_opts++;
                next;
            }
        }
    }
    
    # Fname-likes
    my $num_of_fnames = 0;
    $num_of_fnames = grep $_ !~ /^-/, @_argv;
    $num_of_corr_opts += $num_of_fnames;
    
    # Warn if "no" correct options have been passed.
    if ($num_of_corr_opts == 0) {
        say $_prog_info{usage};
        say "    | None of the command-line options was correct.";
        say "    | Please refer to the usage above.";
        exit;
    }
}


sub pause_shell {
    print "Press enter to exit...";
    while (<STDIN>) { last; }
}
#eof