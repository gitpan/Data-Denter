package Data::Denter;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use vars qw($Width $Comma $Level $TabWidth);
require Exporter;
@ISA = qw(Exporter AutoLoader);
@EXPORT = qw(Indent Undent Denter);
@EXPORT_OK = qw(Dumper);
%EXPORT_TAGS = (all => [@EXPORT, @EXPORT_OK]);
$VERSION = '0.11';
use Carp;

sub Indent {
    Data::Denter->new(width => $Width || 4,
		      level => $Level || 0,
		      comma => $Comma || " => ",
		     )->indent(@_);
};
*Denter = \&Indent;
*Dumper = \&Indent;

sub Undent {
    Data::Denter->new(width => $Width || 4,
		      tabwidth => $TabWidth || 8,
		      comma => $Comma || " => ",
		     )->undent(@_);
};

# General error messages
sub invalid_usage { 
    "Invalid usage of the $_[0] method\n";
}

# Indent error messages
sub invalid_name_level { 
    "Can't indent a typeglob name at indentation level $_[0]\n";
}

# Undent error messages
sub invalid_indent_width { 
    my $o = shift;
    "Invalid indent width detected at line $o->{line}\n";
}

sub no_key_end_marker {
    my ($marker, $line) = @_;
    "No terminating marker '$marker' found for key at line $line\n";
}

sub no_value_end_marker {
    my ($marker, $line) = @_;
    "No terminating marker '$marker' found for value at line $line\n";
}

sub mismatched_quotes {
    my $o = shift;
    "Mismatched double quotes for value at line $o->{line}\n";
}

sub invalid_key_value {
    my $o = shift;
    "Missing or invalid hash key/value pair at $o->{line}\n";
}

sub invalid_indent_level {
    my $o = shift;
    "Invalid indentation level at $o->{line}\n";
}

sub invalid_scalar_value {
    my $o = shift;
    "Invalid value for scalar ref context at $o->{line}\n";
}

sub new {
    my $class = shift;
    my %args = @_;
    bless {__DATA__DENTER__ => 1,
	   width => $args{width} || 4,
	   comma => $args{comma} || " => ",
	   level => $args{level} || 0,
	   tabwidth => $args{tabwidth} || 8,
	  }, $class;
}

sub indent {
    my $o = shift;
    croak invalid_usage('indent') unless $o->{__DATA__DENTER__};
    my $package = caller;
    $package = caller(1) if $package eq 'Data::Denter';
    my $stream = '';
    $o->{key} = '';
    while (@_) {
	$_ = shift;
	$stream .= $o->_indent_name($_, shift), next
	  if (/^\*$package\::\w+$/);
	$stream .= $o->_indent_data($_);
    }
#    print $stream; exit;
    $o->_resolve(\$stream);
    return $stream;
}

sub _indent_data {
    my $o = shift;
    $_ = shift;
    return $o->_indent_undef($_)
      if not defined;
    return $o->_indent_value($_) 
      if (not ref);
    return $o->_indent_hash($_)
      if (ref eq 'HASH' and not /=/ or /=HASH/);
    return $o->_indent_array($_)
      if (ref eq 'ARRAY' and not /=/ or /=ARRAY/);
    return $o->_indent_scalar($_)
      if (ref eq 'SCALAR' and not /=/ or /=SCALAR/);
    return $o->_indent_ref($_)
      if (ref eq 'REF');
    return "$_\n";
}

sub _indent_value {
    my ($o, $data) = @_;
    my $stream;
    if ($data =~ /\n/) {
	my $marker = 'EOV';
	$marker++ while $data =~ /^$marker$/m;
	my $chomp = ($data =~ s/\n\Z//) ? '' : '-';
	$stream = "<<$marker$chomp\n";
	$stream .= $o->{key}, $o->{key} = '' if $o->{key};
	$stream .= "$data\n$marker\n";
    }
    elsif ($data =~ /^[\s\%\@\$\\?\"]|\s$/ or
	   $data =~ /\Q$o->{comma}\E/ or
	   $data =~ /[\x00-\x1f]/ or
	   $data eq '') {
	$stream = qq{"$data"\n};
	$stream .= $o->{key}, $o->{key} = '' if $o->{key};
    }
    else {
	$stream = "$data\n";
	$stream .= $o->{key}, $o->{key} = '' if $o->{key};
    }
    return $stream;
}

sub _indent_hash {
    my ($o, $data) = @_;
    my $stream = $o->_print_ref($data, '%', 'HASH');
    return $$stream if ref $stream;
    my $indent = ++$o->{level} * $o->{width};
    for my $key (keys %$data) {
	my $key_out = $key;
	if ($key =~ /\n/ or
	    $key =~ /\Q$o->{comma}\E/) {
	    my $marker = 'EOK';
	    $marker++ while $key =~ /^$marker$/m;
	    my $chomp = (($o->{key} = $key) =~ s/\n\Z//m) ? '' : '-';
	    $o->{key} .= "\n$marker\n";
	    $key_out = "<<$marker$chomp";
	}
	elsif ($data =~ /^[\s\%\@\$\\?\"]|\s$/) {
	    $key_out = qq{"$key"};
	}
	$stream .= ' ' x $indent . $key_out . $o->{comma};
	$stream .= $o->_indent_data($data->{$key});
    }
    $o->{level}--;
    return $stream;
}

sub _indent_array {
    my ($o, $data) = @_;
    my $stream = $o->_print_ref($data, '@', 'ARRAY');
    return $$stream if ref $stream;
    my $indent = ++$o->{level} * $o->{width};
    for my $datum (@$data) {
	$stream .= ' ' x $indent;
	$stream .= $o->_indent_data($datum);
    }
    $o->{level}--;
    return $stream;
}

sub _indent_scalar {
    my ($o, $data) = @_;
    my $stream = $o->_print_ref($data, q{$}, 'SCALAR');
    return $$stream if ref $stream;
    my $indent = ($o->{level} + 1) * $o->{width};
    $stream .= ' ' x $indent;
    $stream .= $o->_indent_data($$data);
    return $stream;
}

sub _indent_ref {
    my ($o, $data) = @_;
    my $stream = $o->_print_ref($data, '\\', 'SCALAR');
    return $$stream if ref $stream;
    chomp $stream;
    return $stream . $o->_indent_data($$data);
}

sub _indent_undef {
    my ($o, $data) = @_;
    my $stream = "?\n";
    $stream .= $o->{key}, $o->{key} = '' if $o->{key};
    return $stream;
}

sub _indent_name {
    my ($o, $name, $value) = @_;
    $name =~ s/^.*:://;
    croak invalid_name_level($o->{level}) if $o->{level} != 0;
    my $stream = $name . $o->{comma};
    $stream .= $o->_indent_data($value);
    return $stream;
}

sub _print_ref {
    my ($o, $data, $symbol, $type) = @_;
    $data =~ /^(([\w:]+)=)?$type\(0x([0-9a-f]+)\)$/ 
      or croak "Invalid reference: $data\n";
    my $stream = $symbol;
    $stream .= $2 if defined $2;
    $o->{xref}{$3}++;
    if ($o->{xref}{$3} > 1) {
	$stream .= "(*$3)\n";
	$stream .= $o->{key}, $o->{key} = '' if $o->{key};
	return \$stream;
    }
    push @{$o->{refs}}, $3;
    $stream .= "($3)\n";
    $stream .= $o->{key}, $o->{key} = '' if $o->{key};
    return $stream;
}

sub _resolve {
    my ($o, $stream_ref) = @_;
    my $ref_label = 'REF00000';
    local $^W;
    for my $ref (@{$o->{refs}}) {
	if ($o->{xref}{$ref} == 1) {
	    $$stream_ref =~ s/(?:(\\)\($ref\)([\\\%\@\$])|\($ref\)\s*$)/$1$2/m;
	}
	else {
	    $ref_label++;
	    $$stream_ref =~ 
	      s/(?:(\\)\($ref\)([\\\%\@\$])|\($ref\)\s*$)/$1($ref_label)$2/m;
	    my $i = 0;
	    $$stream_ref =~ 
	      s/\(\*$ref\)$/ "(*$ref_label" . '-' . ++$i . ')' /gem;
	      
	}
    }
    $$stream_ref .= "\n" unless $$stream_ref =~ /\n\Z/;
}

sub undent {
    local $/ = "\n";
    my ($o, $text) = @_;
    my ($comma) = $o->{comma};
    croak invalid_usage('undent') unless $o->{__DATA__DENTER__};
    my $package = caller;
    $package = caller(1) if $package eq 'Data::Denter';
    %{$o->{xref}} = ();
    @{$o->{objects}} = ();
    @{$o->{context}} = ();
    my $glob = '';
    chomp $text;
    @{$o->{lines}} = split $/, $text;
    $o->{level} = 0;
    $o->{line} ||= 1;
    $o->_setup_line;
    while (not $o->{done}) {
	if ($o->{level} == 0 and
	    $o->{content} =~ /^(\w+)\s*$comma\s*(.*)$/) {
	    $o->{content} = $2;
	    no strict 'refs';
	    push @{$o->{objects}}, *{"${package}::$1"};
	}
	push @{$o->{objects}}, $o->_undent_data;
    }
    return @{$o->{objects}};
}

sub _undent_data {
    my $o = shift;
    my ($obj, $class) = ('god', '');
    my @refs;
    my %refs;
    local $^W;
    while ($o->{content} =~ s/^\\(?:\((\w+)\))?((\%|\@|\$|\\\(\*|\\).*)/$2/) {
	push @refs, $1;
	$refs{$1} = scalar @refs;
	last if $3 eq '\\(*';
    }
    if ($o->{content} =~ /^([\%\@\$])
	                  (\w(?:\w|::)*)?
                          (?:\((\*)?(\w+)(?:-\d+)?\))?
                          \s*$/x
       ) {
	my $foo;
	$obj = ($1 eq '%') ? {} : ($1 eq '@') ? [] : \$foo;
	$class = $2 || '';
	if ($3) {
	    croak unless defined $o->{xref}{$4};
	    $obj = $o->{xref}{$4};
	    $o->_next_line;
	    $o->_setup_line;
	}
	else {
	    $o->{xref}{$4} = $obj;
	    if ($1 eq '%') {
		%$obj = $o->_undent_hash;
	    } 
	    elsif ($1 eq '@') {
		@$obj = $o->_undent_array;
	    } 
	    else {
		$$obj = $o->_undent_scalar;
	    } 
	    bless $obj, $class if length $class;
	}
    }
    elsif ($o->{content} =~ /^\\\(\*(\w+)-\d+\)\s*$/
       ) {
	my $refs = @refs;
	while (@refs) {
	    my $ref = pop @refs;
	    my $copy = $obj;
	    $obj = \ $copy;
	    $o->{xref}{$ref} = $obj if $ref;
	}
	croak "screwed" unless defined $o->{xref}{$1};
	eval("\$" x $refs . '$obj = $o->{xref}{$1}');
	$o->_next_line;
	$o->_setup_line;
    }
    elsif ($o->{content} =~ /^\?\s*$/) {
	$obj = $o->_undent_undef;
    }
    else {
	$obj = $o->_undent_value;
    }
    while (@refs) {
	my $ref = pop @refs;
	my $copy = $obj;
	$obj = \ $copy;
	$o->{xref}{$ref} = $obj if $ref;
    }
    return $obj;
}

sub _undent_value {
    my $o = shift;
    my $value = '';
    if ($o->{content} =~ /^\<\<(\w+)(\-?)\s*$/) {
	my ($marker, $chomp) = ($1, $2);
	my $line = $o->{line};
	$o->_next_line;
	while (not $o->{done} and
	       $o->{lines}[0] ne $marker) {
	    $value .= $o->{lines}[0] . "\n";
	    $o->_next_line;
	}
	croak no_value_end_marker($marker, $line) if $o->{done};
	chomp $value if $chomp;
    }
    elsif ($o->{content} =~ /^\"/) {
	croak $o->mismatched_quotes unless $o->{content} =~ /^\".*\"\s*$/;
	($value = $o->{content}) =~ s/^\"|\"\s*$//g;
    }
    else {
	$value = $o->{content};
    }
    $o->_next_line;
    $o->_setup_line;
    return $value;
}

sub _undent_hash {
    my @values;
    my $o = shift;
    my $level = $o->{level} + 1;
    $o->_next_line;
    $o->_setup_line;
    while ($o->{level} == $level) {
	my ($key, $value) = split $o->{comma}, $o->{content};
	croak $o->invalid_key_value unless (defined $key and defined $value);
	$o->{content} = $value;
	push @values, $o->_get_key($key), $o->_undent_data;;
    }
    croak $o->invalid_indent_level if $o->{level} > $level;
    return @values;
}

sub _get_key {
    my ($o, $key) = @_;
    return $key unless $key =~ /^\<\<(\w+)(\-?)/;
    my ($marker, $chomp) = ($1, $2);
    $key = '';
    my $line = $o->{line};
    $o->_next_line;
    while (not $o->{done} and
	   $o->{lines}[0] ne $marker) {
	$key .= $o->{lines}[0] . "\n";
	$o->_next_line;
    }
    croak no_key_end_marker($marker, $line) if $o->{done};
    chomp $key if $chomp;
    $o->_next_line;
    $o->_setup_line;
    return $key;
}

sub _undent_array {
    my @values;
    my $o = shift;
    my $level = $o->{level} + 1;
    $o->_next_line;
    $o->_setup_line;
    while ($o->{level} == $level) {
	push @values, $o->_undent_data;
    }
    croak $o->invalid_indent_level if $o->{level} > $level;
    return @values;
}

sub _undent_scalar {
    my $values;
    my $o = shift;
    my $level = $o->{level} + 1;
    $o->_next_line;
    $o->_setup_line;
    croak $o->invalid_indent_level if $o->{level} != $level;
    croak $o->invalid_scalar_value if $o->{content} =~ /^[\%\@\$\\]/;
    return $o->_undent_undef if $o->{content} =~ /^\?/;
    return $o->_undent_value;
}

sub _undent_undef {
    my $o = shift;
    $o->_next_line;
    $o->_setup_line;
    return undef;
}

sub _next_line {
    my $o = shift;
    $o->{done}++, $o->{level} = -1, return unless @{$o->{lines}};
    $_ = shift @{$o->{lines}};
    $o->{line}++;
}

sub _setup_line {
    my $o = shift;
    $o->{done}++, $o->{level} = -1, return unless @{$o->{lines}};
    my ($width, $tabwidth) = @{$o}{qw(width tabwidth)};
    while (1) {
	$_ = $o->{lines}[0];
	# expand tabs in leading whitespace;
	$o->next_line, next if /^(\s*$|\#)/; # skip comments and blank lines
	while (s{^( *)(\t+)}
	       {' ' x (length($1) + length($2) * $tabwidth - 
		       length($1) % $tabwidth)}e){}
	croak $o->invalid_indent_width unless /^(( {$width})*)(\S.*)$/;
	$o->{level} = length($1) / $width;
	$o->{content} = $3;
	last;
    }
}

1;

__END__
