use strict;
use Test;
use Data::Denter;
use Data::Dumper;
BEGIN { plan test => 1 }

my $test = 0;
system "clear" if $ENV{DEBUG};

#1
my $name = *name; # just to turn off "used once" warning.
my $foo1 = bless {count => \[qw(one two three four), \\undef]}, "Bugle::Boy";
Test_This(*name => $foo1);

#2
my $a = \\\\'pizza';
my $b = $$a;
Test_This([$a,$b]);

#3
my $c;
$c = \\$c;
Test_This($c);

#4
my $d = 42;
$d = [\$d];
Test_This($d);

#5
my ($e, $f);
$e = \$f;
$f = \$e;
Test_This([$e,$f]);

#6
Test_This (bless {[], {}});

sub Test_This {
    print "=" x 30 . " Test #" . ++$test . " " . "=" x 30 . "\n" 
      if $ENV{DEBUG};
    my $dump1 = Dumper @_;
    print $dump1 if $ENV{DEBUG};
    my $dent1 = Indent @_;
    print $dent1 if $ENV{DEBUG};
    my $dump2 = Dumper(Undent $dent1);
    print $dump2 if $ENV{DEBUG};
    ok($dump2 eq $dump1);
}
