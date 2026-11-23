#!perl

# Author test: run with `prove -l xt/`.

use strict;
use warnings;

use Test::More;

eval { require Test::Pod; Test::Pod->VERSION('1.41'); 1 }
    or plan skip_all => 'Test::Pod 1.41 is required for this test';

Test::Pod::all_pod_files_ok();
