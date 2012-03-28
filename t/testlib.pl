use 5.010;
use strict;
use warnings;

use File::Slurp;
use Setup::Text::Snippet::WithID qw(setup_snippet_with_id);
use Test::More 0.96;
use Test::Setup qw(test_setup);

sub setup {
}

sub teardown {
    done_testing();
}

sub test_setup_snippet_with_id {
    my %tssargs = @_;

    my %tsargs;
    for (qw/check_setup check_unsetup check_state1 check_state2
            name dry_do_error do_error set_state1 set_state2 prepare cleanup/) {
        $tsargs{$_} = $tssargs{$_};
    }
    $tsargs{function} = \&setup_snippet_with_id;

    my %fargs = %{ $tssargs{args} };
    $tsargs{args} = \%fargs;
    my $f = $fargs{file};

    my $check = sub {
        my %cargs = @_;

        my $exists = (-e $f);

        if ($cargs{exists} // 1) {
            ok($exists, "exists") or return;

            if (defined $cargs{content}) {
                my $content = read_file($f);
                if (ref($cargs{content}) eq 'Regexp') {
                    like($content, $cargs{content}, "content");
                } else {
                    is($content, $cargs{content}, "content");
                }
            }

        } else {
            ok(!$exists, "does not exist");
        }
    };

    $tsargs{check_setup}   = sub { $check->(%{$tssargs{check_setup}}) };
    $tsargs{check_unsetup} = sub { $check->(%{$tssargs{check_unsetup}}) };
    if ($tssargs{check_state1}) {
        $tsargs{check_state1} = sub { $check->(%{$tssargs{check_state1}}) };
    }
    if ($tssargs{check_state2}) {
        $tsargs{check_state2} = sub { $check->(%{$tssargs{check_state2}}) };
    }

    test_setup(%tsargs);
}

1;
