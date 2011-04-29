#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use File::Slurp;
use File::Temp qw(tempfile);
use Test::More 0.96;
require "testlib.pl";

use vars qw($redo_data $undo_data);

setup();

my ($fh, $f) = tempfile();
write_file($f, "1\n2\n3\n");

test_setup_snippet_with_id(
    name       => "insert one-line (dry run)",
    args       => {file=>$f, id=>"id1", content=>"x",
                   -dry_run=>1},
    status     => 200,
    content    => "1\n2\n3\n",
);
test_setup_snippet_with_id(
    name       => "insert one-line",
    args       => {file=>$f, id=>"id1", content=>"x",
                   },
    status     => 200,
    content    => "1\n2\n3\nx # SNIPPET id=id1\n",
);

# XXX test: autoappend ending newline for file
# XXX test: autoappend ending newline for multiline content

DONE_TESTING:
teardown();
