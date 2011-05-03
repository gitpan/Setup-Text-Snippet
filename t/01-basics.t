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
    name       => "insert one-line/shell (dry run)",
    args       => {file=>$f, id=>"id1", content=>"x",
                   -dry_run=>1},
    status     => 200,
    content    => "1\n2\n3\n",
);
test_setup_snippet_with_id(
    name       => "insert one-line/shell (with undo)",
    args       => {file=>$f, id=>"id1", content=>"x",
                   -undo_action=>"do"},
    status     => 200,
    content    => "1\n2\n3\nx # SNIPPET id=id1\n",
    posttest   => sub {
        my ($res) = @_;
        $undo_data = $res->[3]{undo_data};
    },
);
test_setup_snippet_with_id(
    name       => "insert one-line/shell (undo)",
    args       => {file=>$f, id=>"id1", content=>"x",
                   -undo_action=>"undo", -undo_data=>$undo_data},
    status     => 200,
    content    => "1\n2\n3\n",
    posttest   => sub {
        my ($res) = @_;
        $redo_data = $res->[3]{undo_data};
    },
);
test_setup_snippet_with_id(
    name       => "insert one-line/shell (repeat undo)",
    args       => {file=>$f, id=>"id1", content=>"x",
                   -undo_action=>"undo", -undo_data=>$undo_data},
    status     => 304,
    content    => "1\n2\n3\n",
);
test_setup_snippet_with_id(
    name       => "insert one-line/shell (redo)",
    args       => {file=>$f, id=>"id1", content=>"x",
                   -undo_action=>"undo", -undo_data=>$redo_data},
    status     => 200,
    content    => "1\n2\n3\nx # SNIPPET id=id1\n",
);

write_file($f, "1\n2\n3");
test_setup_snippet_with_id(
    name       => "insert multiline/shell, autoappend newline on file (w undo)",
    args       => {file=>$f, id=>"i", content=>"x\ny\n",
                   -undo_action=>"do"},
    status     => 200,
    content    => "1\n2\n3\n# BEGIN SNIPPET id=i\nx\ny\n# END SNIPPET id=i\n",
    posttest   => sub {
        my ($res) = @_;
        $undo_data = $res->[3]{undo_data};
    },
);
test_setup_snippet_with_id(
    name       => "insert multiline/shell, autoappend newline on file (undo)",
    args       => {file=>$f, id=>"i", content=>"x\ny\n",
                   -undo_action=>"undo", -undo_data=>$undo_data},
    status     => 200,
    content    => "1\n2\n3\n",
    posttest   => sub {
        my ($res) = @_;
        $redo_data = $res->[3]{undo_data};
    },
);
test_setup_snippet_with_id(
    name       => "insert multiline/shell, autoappend newline on file (redo)",
    args       => {file=>$f, id=>"i", content=>"x\ny\n",
                   -undo_action=>"undo", -undo_data=>$redo_data},
    status     => 200,
    content    => "1\n2\n3\n# BEGIN SNIPPET id=i\nx\ny\n# END SNIPPET id=i\n",
);

write_file($f, "1\n2\n3");
test_setup_snippet_with_id(
    name       => "insert one-line/cpp, autoappend newline on file",
    args       => {file=>$f, id=>"i", content=>"x", comment_style=>'cpp'},
    status     => 200,
    content    => "1\n2\n3\nx // SNIPPET id=i\n",
);
write_file($f, "1\n2\n3\n");
test_setup_snippet_with_id(
    name       => "insert multiline/cpp, autoappend newline on snippet",
    args       => {file=>$f, id=>"i", content=>"x\ny", comment_style=>'cpp'},
    status     => 200,
    content    => "1\n2\n3\n// BEGIN SNIPPET id=i\nx\ny\n// END SNIPPET id=i\n",
);
write_file($f, "1\n2\n3\n");
test_setup_snippet_with_id(
    name       => "insert one-line/c, label (string)",
    args       => {file=>$f, id=>"i", content=>" x", label=>"Label",
                   comment_style=>'c'},
    status     => 200,
    content    => "1\n2\n3\n x /* Label id=i */\n",
);
write_file($f, "1\n2\n3\n");
test_setup_snippet_with_id(
    name       => "insert multiline/c, label (string)",
    args       => {file=>$f, id=>"i", content=>" x\n y\n", label=>"Lbl",
                   comment_style=>'c'},
    status     => 200,
    content    => "1\n2\n3\n/* BEGIN Lbl id=i */\n x\n y\n/* END Lbl id=i */\n",
);
write_file($f, "");
test_setup_snippet_with_id(
    name       => "insert one-line/html, autotrim",
    args       => {file=>$f, id=>"i", content=>"x  ", comment_style=>'html'},
    status     => 200,
    content    => "x <!-- SNIPPET id=i -->\n",
);
write_file($f, "");
test_setup_snippet_with_id(
    name       => "insert multiline/html",
    args       => {file=>$f, id=>"i", content=>"x  \n y",
                   comment_style=>'html'},
    status     => 200,
    content    => "<!-- BEGIN SNIPPET id=i -->\nx  \n y\n".
        "<!-- END SNIPPET id=i -->\n",
);
write_file($f, "1\n2");
test_setup_snippet_with_id(
    name       => "insert one-line/ini, top_style",
    args       => {file=>$f, id=>"i", content=>"x", comment_style=>'ini',
                   top_style=>1},
    status     => 200,
    content    => "x ; SNIPPET id=i\n1\n2",
);
write_file($f, "1\n2");
test_setup_snippet_with_id(
    name       => "insert multiline/ini, top_style",
    args       => {file=>$f, id=>"i", content=>"x\ny", comment_style=>'ini',
                   top_style=>1},
    status     => 200,
    content    => "; BEGIN SNIPPET id=i\nx\ny\n; END SNIPPET id=i\n1\n2",
);

write_file($f, "1 # SNIPPET attr1=a id=i2 attr2=b\n");
test_setup_snippet_with_id(
    name       => "remove, attrs (with undo)",
    args       => {file=>$f, id=>"i2", content=>"x", should_exist=>0,
                   -undo_action=>"do"},
    status     => 200,
    content    => "",
    posttest   => sub {
        my ($res) = @_;
        $undo_data = $res->[3]{undo_data};
    },
);
test_setup_snippet_with_id(
    name       => "remove, attrs (undo)",
    args       => {file=>$f, id=>"i2", content=>"x", should_exist=>0,
                   -undo_action=>"undo", -undo_data=>$undo_data},
    status     => 200,
    content    => "1 # SNIPPET id=i2\n",
    # currently attrs not recorded in undo data
);

unlink $f;
test_setup_snippet_with_id(
    name       => "file doesn't exist, should_exist=1",
    args       => {file=>$f, id=>"i", content=>"x", should_exist=>1},
    status     => 500,
    exists     => 0,
);
test_setup_snippet_with_id(
    name       => "file doesn't exist, should_exist=1",
    args       => {file=>$f, id=>"i", content=>"x", should_exist=>0},
    status     => 304,
    exists     => 0,
);

write_file($f, "1\n2\n3\n");
test_setup_snippet_with_id(
    name       => "insert, replace_pattern",
    args       => {file=>$f, id=>"i", content=>"x",
                   replace_pattern=>qr/^2\n/m},
    status     => 200,
    content    => "1\nx # SNIPPET id=i\n3\n",
);
write_file($f, "1\n2\n3\n");
test_setup_snippet_with_id(
    name       => "insert, replace_pattern (not found)",
    args       => {file=>$f, id=>"i", content=>"x",
                   replace_pattern=>qr/^4\n/m},
    status     => 200,
    content    => "1\n2\n3\nx # SNIPPET id=i\n",
);
write_file($f, "1\n2\n3\n");
test_setup_snippet_with_id(
    name       => "insert, good_pattern",
    args       => {file=>$f, id=>"i", content=>"x",
                   good_pattern=>qr/^2\n/m},
    status     => 304,
    content    => "1\n2\n3\n",
);

# XXX test: label (coderef)

DONE_TESTING:
teardown();
