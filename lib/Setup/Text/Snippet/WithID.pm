package Setup::Text::Snippet::WithID;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

use File::Slurp;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(setup_snippet_with_id);

our $VERSION = '0.05'; # VERSION

our %SPEC;

sub _label {
    my %args  = @_;
    my $id    = $args{id} // "";
    my $label = $args{label};
    my $comment_style = $args{comment_style};

    my $attrs_re = qr/(?:\w+=\S+\s+)*id=\Q$id\E(?:\s+\w+=\S+)*/;
    my ($ts, $te);
    if ($comment_style eq 'shell') {
        $ts = "#";
        $te = "";
    } elsif ($comment_style eq 'c') {
        $ts = "/*";
        $te = "*/";
    } elsif ($comment_style eq 'cpp') {
        $ts = "//";
        $te = "";
    } elsif ($comment_style eq 'html') {
        $ts = "<!--";
        $te = "-->";
    } elsif ($comment_style eq 'ini') {
        $ts = ";";
        $te = "";
    } else {
        die "BUG: unknown comment_style $comment_style";
    }
    my $ore = qr!^(.*?)\s*
                 \Q$ts\E\s*\Q$label\E\s+$attrs_re\s*\Q$te\E\s*(?:\R|\z)!mx;
    my $mre = qr!^\Q$ts\E\s*BEGIN\s+\Q$label\E\s+$attrs_re\s*\Q$te\E\s*\R
                 (.*?)
                 ^\Q$ts\E\s*END  \s+\Q$label\E\s+$attrs_re\s*\Q$te\E
                 \s*(?:\R|\z)!msx;

    return {
        one_line_comment => " $ts $label id=$id" . ($te ? " $te":""),
        begin_comment => "$ts BEGIN $label id=$id" . ($te ? " $te":""),
        end_comment => "$ts END $label id=$id" . ($te ? " $te":""),
        one_line_pattern => $ore,
        multi_line_pattern => $mre,
    };
}

$SPEC{setup_snippet_with_id} = {
    summary  => "Setup text snippet (with comment containing ID) in file",
    description => <<'_',

On do, will insert a snippet of text with specified ID to a file, if it doesn't
already exist. Usually used for inserting tidbits of configuration into
configuration files.

Snippets are enclosed with comment (shell-style by default, or alternatively
C++/C-style) giving them ID. Example of one-line snippet:

 some text # SNIPPET id=id1

Example of multi-line snippet (using C++-style comment instead of shell-style):

 // BEGIN SNIPPET id=id2
 some
 lines
 of
 text
 // END SNIPPET

On undo, will remove the snippet.

_
    args => {
        file => ['str*' => {
            summary => 'File name',
            description => <<'_',

File must already exist.

_
        }],
        id => ['str*' => {
            summary => 'Snippet ID',
            match   => qr/\A[\w-]+\z/,
        }],
        content => ['str*' => {
            summary => 'Snippet text',
            description => <<'_',

String containing text).

_
        }],
        should_exist => ['bool' => {
            summary => 'Whether snippet should exist',
            description => <<'_',

You can set this to false if you want to ensure snippet doesn't exist.

_
            default => 1,
        }],
        top_style => ['bool' => {
            summary => 'Whether to append snippet at beginning of file '.
                'instead of at the end',
            description => <<'_',

Default is false, which means to append at the end of file.

Note that this only has effect if replace_pattern is not defined or replace
pattern is not found in file. Otherwise, snippet will be inserted to replace the
pattern.

_
            default => 0,
        }],
        replace_pattern => ['str' => {
            summary => 'Regex pattern which if found will be used for '.
                'placement of snippet',
            description => <<'_',

If snippet needs to be inserted into file, then if replace_pattern is defined
then it will be searched. If found, snippet will be placed to replace the
pattern. Otherwise, snippet will be inserted at the end (or beginning, see
top_style) of file.

_
        }],
        good_pattern => ['str' => {
            summary => 'Regex pattern which if found means snippet '.
                'need not be inserted',
        }],
        comment_style => ['str' => {
            summary => 'Comment style',
            in => [qw/c cpp html shell ini/],
            default => 'shell',
            description => <<'_',

Snippet is inserted along with comment which contains meta information such as
snippet ID (so it can be identified and updated/removed later when necessary).

Example of shell-style (shell) comment:

 ... # SNIPPET id=...

 # BEGIN SNIPPET id=...
 ...
 # END SNIPPET

Example of C-style (c) comment:

 .... /* SNIPPET id=... */

 /* BEGIN SNIPPET id=... */
 ...
 /* END SNIPPET id=... */

Example of C++-style (cpp) comment:

 .... // SNIPPET id=...

 // BEGIN SNIPPET id=...
 ...
 // END SNIPPET id=...

Example of SGML-style (html) comment:

 .... <!-- SNIPPET id=... -->

 <!-- BEGIN SNIPPET id=... -->
 ...
 <!-- END SNIPPET id=... -->

Example of INI-style comment:

 .... // SNIPPET id=...

 ; BEGIN SNIPPET id=...
 ...
 ; END SNIPPET id=...

_
        }],
        label => ['any' => {
            of => ['str*', 'code*'],
            default => 'SNIPPET',
            summary => 'Comment label',
            description => <<'_',

If label is string (e.g. 'Foo'), then one-line snippet comment will be:

 # Foo id=...

and multi-line snippet comment:

 # BEGIN Foo id=...
 ...
 # END Foo id=...

If label is coderef, it will be called with named arguments: id, comment_style.
It must return a hash with these keys: one_line_comment, begin_comment,
end_comment, one_line_pattern (regex to match snippet content and extract it in
$1), and multi_line_pattern (regex to match snippet content and extract it in
$1).

_
        }],
    },
    features => {undo=>1, dry_run=>1},
};
sub setup_snippet_with_id {
    my %args           = @_;
    my $dry_run        = $args{-dry_run};
    my $undo_action    = $args{-undo_action} // "";

    # check args
    my $file           = $args{file};
    defined($file) or return [400, "Please specify file"];
    my $id             = $args{id};
    defined($id) or return [400, "Please specify id"];
    $id =~ /\A[\w-]+\z/
        or return [400, "Invalid id, please only use alphanums/dashes"];
    my $should_exist    = $args{should_exist} // 1;
    my $replace_pattern = $args{replace_pattern};
    my $good_pattern    = $args{good_pattern};
    my $top_style       = $args{top_style} // 0;
    defined($args{content}) or return [400, "Please specify content"];

    my ($label, $label_sub);
    if (ref($args{label}) eq 'CODE') {
        $label = "SNIPPET";
        $label_sub = $args{label};
    } else {
        $label = $args{label} // "SNIPPET";
        $label_sub = \&_label;
    }
    my $comment_style      = $args{comment_style} // "shell";
    my $res                = $label_sub->(id=>$id, label=>$label,
                                          comment_style=>$comment_style);
    my $one_line_comment   = $res->{one_line_comment};
    my $begin_comment      = $res->{begin_comment};
    my $end_comment        = $res->{end_comment};
    my $one_line_pattern   = $res->{one_line_pattern};
    my $multi_line_pattern = $res->{multi_line_pattern};

    # collect steps
    my $steps;
    if ($undo_action eq 'undo') {
        $steps = $args{-undo_data} or return [400, "Please supply -undo_data"];
    } else {
        $steps = [];
        if ($should_exist) { push @$steps, ["insert"] }
        else               { push @$steps, ["remove"] }
    }

    my $save_undo = $undo_action ? 1:0;
    return [400, "Invalid steps, must be an array"]
        unless $steps && ref($steps) eq 'ARRAY';

    # perform the steps
    my $rollback;
    my $undo_steps = [];
    my $changed;
  STEP:
    for my $i (0..@$steps-1) {
        my $step = $steps->[$i];
        $log->tracef("step %d of 0..%d: %s", $i, @$steps-1, $step);
        my $err;
        return [400, "Invalid step (not array)"] unless ref($step) eq 'ARRAY';

        if ($step->[0] eq 'insert' || $step->[0] eq 'remove') {

            my $content = $step->[1] // $args{content};
            my $is_multi = $content =~ /\R/;
            if ($is_multi) {
                # autoappend newline
                $content =~ s/\R\z//; $content .= "\n";
            } else {
                # autotrim one-line
                $content =~ s/\s+\z//;
            }

            if (!(-f $file)) {
                if ($step->[0] eq 'insert') {
                    $err = "Must insert snippet, but file doesn't exist";
                    goto CHECK_ERR;
                } else {
                    $log->info("File doesn't exist, skipping step");
                    next STEP;
                }
            }
            my $str = read_file($file, err_mode=>'quiet');
            if (!defined($str)) {
                $err = "Can't read file $file: $!";
                goto CHECK_ERR;
            }
            my $typ;
            my $ct;
            my $do_remove;
            my $do_insert;
            if ($str =~ /$one_line_pattern/ && ($typ = 'oneline') ||
                    $str =~ /$multi_line_pattern/ && ($typ = 'multi')) {
                $ct = $1;
                if ($step->[0] eq 'insert' && $ct ne $content) {
                    $log->infof("nok: file %s: snippet content is >>>%s<<< ".
                                    "but needs to be >>>%s<<<",
                                $file, $ct, $content);
                    $do_insert++;
                } elsif ($step->[0] eq 'remove') {
                    $log->info("nok: file $file: snippet exists when ".
                                   "it should be removed");
                } else {
                    next STEP;
                }
                return [200, "dry run"] if $dry_run;
                $do_remove++;
                if ($typ eq 'oneline') {
                    $str =~ s/$one_line_pattern//;
                } else {
                    $str =~ s/$multi_line_pattern//;
                }
            } else {
                if ($step->[0] eq 'remove') {
                    # file already lacks snippet
                    next STEP;
                } else {
                    if ($good_pattern && $str =~ /$good_pattern/) {
                        $log->debugf(
                            "File contains good_pattern %s, so we don't need ".
                                "to insert snippet", $good_pattern);
                    } else {
                        $log->info("nok: file $file: snippet doesn't exist");
                        $do_insert++;
                    }
                }
            }

            if ($do_insert) {
                return [200, "dry run"] if $dry_run;
                my $snippet;
                if ($is_multi) {
                    $snippet = join(
                        "",
                        $begin_comment, "\n",
                        $content,
                        $end_comment, "\n"
                    );
                } else {
                    $snippet = $content . $one_line_comment . "\n";
                }
                if ($replace_pattern && $str =~ /$replace_pattern/) {
                    $str =~ s/$replace_pattern/$snippet/;
                } elsif ($top_style) {
                    $str = $snippet . $str;
                } else {
                    $str .= ($str =~ /\R\z/ || !length($str) ? "" : "\n") .
                        $snippet;
                }
            }

            if ($do_insert || $do_remove) {
                $log->tracef("Updating file %s ...", $file);
                if (!write_file($file, {err_mode=>'quiet', atomic=>1}, $str)) {
                    $err = "Can't write file: $!";
                    goto CHECK_ERR;
                }
                $changed++;

                if ($step->[0] eq 'remove') {
                    unshift @$undo_steps, ['insert', $ct];
                } else {
                    unshift @$undo_steps, ['remove'];
                }
            }

        } else {

            die "BUG: Unknown step command: $step->[0]";

        }
      CHECK_ERR:
        if ($err) {
            if ($rollback) {
                die "Failed rollback step $i of 0..".(@$steps-1).": $err";
            } else {
                $log->tracef("Step failed: $err, performing rollback (%s)...",
                             $undo_steps);
                $rollback = $err;
                $steps = $undo_steps;
                goto STEP; # perform steps all over again
            }
        }
    }
    return [500, "Error (rollbacked): $rollback"] if $rollback;

    my $data = undef;
    my $meta = {};
    $meta->{undo_data} = $undo_steps if $save_undo;
    $log->tracef("meta: %s", $meta);
    return [$changed ? 200:304, $changed?"OK":"Nothing done", $data, $meta];
}

1;
# ABSTRACT: Setup text snippet (with comment containing ID) in file_


__END__
=pod

=head1 NAME

Setup::Text::Snippet::WithID - Setup text snippet (with comment containing ID) in file_

=head1 VERSION

version 0.05

=head1 SYNOPSIS

 use Setup::Text::Snippet::WithID 'setup_snippet_with_id';

 my $res = setup_snippet_with_id
     file    => '/etc/default/rsync',
     id      => 'enable',
     content => 'RSYNC_ENABLE=1',
     good_pattern    => qr/^RSYNC_ENABLE\s*=\s*1/m,
     replace_pattern => qr/^RSYNC_ENABLE\s*=.+/m;
 die unless $res->[0] == 200;

Resulting /etc/default/rsync:

 RSYNC_ENABLE=1 # SNIPPET id=enable

The above code's goal is to enable rsync daemon by default. If
/etc/default/rsync already contains the "good pattern"
(qr/^RSYNC_ENABLE\s*=\s*1/m), it will not be inserted with snippet. Snippet will
replace text specified in replace_pattern (or if replace_pattern is not defined,
snippet will be appended to the end of file [or beginning of file if
top_style=>1]).

Example of multi-line snippet, in INI-style comment instead of shell-style:

 ; BEGIN SNIPPET id=default
 register_globals=On
 extension=mysql.so
 extension=gd.so
 memory_limit=256M
 post_max_size=64M
 upload_max_filesize=64M
 browscap=/c/share/php/browscap.ini
 allow_url_fopen=0
 ; END SNIPPET id=default

=head1 DESCRIPTION

This module provides one function: B<setup_snippet_with_id>.

This module is part of the Setup modules family.

This module uses L<Log::Any> logging framework.

This module has L<Rinci> metadata.

=head1 THE SETUP MODULES FAMILY

I use the C<Setup::> namespace for the Setup modules family. See C<Setup::File>
for more details on the goals, characteristics, and implementation of Setup
modules family.

=head1 FUNCTIONS

None are exported by default, but they are exportable.

=head2 setup_snippet_with_id(%args) -> [STATUS_CODE, ERR_MSG, RESULT]


Setup text snippet (with comment containing ID) in file.

On do, will insert a snippet of text with specified ID to a file, if it doesn't
already exist. Usually used for inserting tidbits of configuration into
configuration files.

Snippets are enclosed with comment (shell-style by default, or alternatively
C++/C-style) giving them ID. Example of one-line snippet:

 some text # SNIPPET id=id1

Example of multi-line snippet (using C++-style comment instead of shell-style):

 // BEGIN SNIPPET id=id2
 some
 lines
 of
 text
 // END SNIPPET

On undo, will remove the snippet.

Returns a 3-element arrayref. STATUS_CODE is 200 on success, or an error code
between 3xx-5xx (just like in HTTP). ERR_MSG is a string containing error
message, RESULT is the actual result.

This function supports undo operation. See L<Sub::Spec::Clause::features> for
details on how to perform do/undo/redo.

This function supports dry-run (simulation) mode. To run in dry-run mode, add
argument C<-dry_run> => 1.

Arguments (C<*> denotes required arguments):

=over 4

=item * B<comment_style> => I<str> (default C<"shell">)

Value must be one of:

 ["c", "cpp", "html", "shell", "ini"]


Comment style.

Snippet is inserted along with comment which contains meta information such as
snippet ID (so it can be identified and updated/removed later when necessary).

Example of shell-style (shell) comment:

 ... # SNIPPET id=...

 # BEGIN SNIPPET id=...
 ...
 # END SNIPPET

Example of C-style (c) comment:

 .... /* SNIPPET id=... */

 /* BEGIN SNIPPET id=... */
 ...
 /* END SNIPPET id=... */

Example of C++-style (cpp) comment:

 .... // SNIPPET id=...

 // BEGIN SNIPPET id=...
 ...
 // END SNIPPET id=...

Example of SGML-style (html) comment:

 .... <!-- SNIPPET id=... -->

 <!-- BEGIN SNIPPET id=... -->
 ...
 <!-- END SNIPPET id=... -->

Example of INI-style comment:

 .... // SNIPPET id=...

 ; BEGIN SNIPPET id=...
 ...
 ; END SNIPPET id=...

=item * B<content>* => I<str>

Snippet text.

String containing text).

=item * B<file>* => I<str>

File name.

File must already exist.

=item * B<good_pattern> => I<str>

Regex pattern which if found means snippet need not be inserted.

=item * B<id>* => I<str>

Snippet ID.

=item * B<label> => I<code|str> (default C<"SNIPPET">)

Comment label.

If label is string (e.g. 'Foo'), then one-line snippet comment will be:

 # Foo id=...

and multi-line snippet comment:

 # BEGIN Foo id=...
 ...
 # END Foo id=...

If label is coderef, it will be called with named arguments: id, comment_style.
It must return a hash with these keys: one_line_comment, begin_comment,
end_comment, one_line_pattern (regex to match snippet content and extract it in
$1), and multi_line_pattern (regex to match snippet content and extract it in
$1).

=item * B<replace_pattern> => I<str>

Regex pattern which if found will be used for placement of snippet.

If snippet needs to be inserted into file, then if replace_pattern is defined
then it will be searched. If found, snippet will be placed to replace the
pattern. Otherwise, snippet will be inserted at the end (or beginning, see
top_style) of file.

=item * B<should_exist> => I<bool> (default C<1>)

Whether snippet should exist.

You can set this to false if you want to ensure snippet doesn't exist.

=item * B<top_style> => I<bool> (default C<0>)

Whether to append snippet at beginning of file instead of at the end.

Default is false, which means to append at the end of file.

Note that this only has effect if replace_pattern is not defined or replace
pattern is not found in file. Otherwise, snippet will be inserted to replace the
pattern.

=back

=head1 BUGS/TODOS/LIMITATIONS

If a snippet is removed due to should_exist=>0, its position is not recorded.
Thus the undo step will reinsert snippet according to replace_pattern/top_style
instead of the original position.

The undo also currently doesn't record whether newline was autoappended on the
file, so it doesn't restore that.

TODO: Restore attrs.

=head1 SEE ALSO

Other modules in Setup:: namespace.

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

