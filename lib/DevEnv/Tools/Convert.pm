package DevEnv::Tools::Convert;

our $MULTI_K = 1_024;
our $MULTI_M = 1_048_576;
our $MULTI_G = 1_073_741_824;
our $MULTI_T = 1_099_511_627_776;

sub convert_to_full_number {

	my $class = shift;
	my $value = shift;

	if ( defined $value ) {

		my $multi = 1;
		if ( $value =~ m/k/i ) {
			$multi = $MULTI_K;
		}
		elsif ( $value =~ m/m/i ) {
			$multi = $MULTI_M;
		}
		elsif ( $value =~ m/g/i ) {
			$multi = $MULTI_G;
		}
		elsif ( $value =~ m/t/i ) {
			$multi = $MULTI_T;
		}

		$value =~ s/[^\d]//g;

		$value *= $multi;
	}

	return $value;
}

sub _convert_value_to {

	my $class   = shift;
	my %args    = @_;

	my $value   = $args{value};
	my $divider = $args{divider};
	my $symbol  = $args{symbol};

	if ( defined $value ) {

		if ( $value == 0 ) {
			$value = "0";
		}
		else {
			$value = int( ( $value / $divider ) + 0.9 );
		}
	}

	return $value;
}

sub convert_value_to_K {

	my $class = shift;
	my $value = shift;

	return $class->_convert_value_to(
		value   => $value,
		divider => $MULTI_K,
		symbol  => "K"
	);
}

sub convert_value_to_M {

	my $class = shift;
	my $value = shift;

	return $class->_convert_value_to(
		value   => $value,
		divider => $MULTI_M,
		symbol  => "M"
	);
}

sub convert_value_to_G {

	my $class = shift;
	my $value = shift;

	return $class->_convert_value_to(
		value   => $value,
		divider => $MULTI_G,
		symbol  => "G"
	);
}

sub convert_value_to_T {

	my $class = shift;
	my $value = shift;

	return $class->_convert_value_to(
		value   => $value,
		divider => $MULTI_T,
		symbol  => "T"
	);
}

1;
