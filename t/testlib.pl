use 5.010;
use strict;
use warnings;

use File::Slurp;
use Setup::Text::Snippet::WithID qw(setup_snippet_with_id);
use Test::More 0.96;

sub setup {
}

sub teardown {
    done_testing();
}

sub test_setup_snippet_with_id {
    my %args = @_;
    subtest "$args{name}" => sub {

        my $f = $args{args}{file};

        if ($args{presetup}) {
            $args{presetup}->();
        }

        my $res;
        eval { $res = setup_snippet_with_id(%{$args{args}}) };
        my $eval_err = $@;

        if ($args{dies}) {
            ok($eval_err, "dies");
        } else {
            ok(!$eval_err, "doesn't die") or diag $eval_err;
        }

        #diag explain $res;
        if ($args{status}) {
            is($res->[0], $args{status}, "status $args{status}")
                or diag explain($res);
        }

        my $exists = (-e $f);

        if ($args{exists} // 1) {
            ok($exists, "exists") or return;

            if (defined $args{content}) {
                my $content = read_file($f);
                is($content, $args{content}, "content");
            }

        } else {
            ok(!$exists, "does not exist");
        }

        if ($args{posttest}) {
            $args{posttest}->($res);
        }

    };
}

1;
