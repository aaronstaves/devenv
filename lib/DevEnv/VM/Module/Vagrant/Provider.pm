package DevEnv::VM::Module::Vagrant::Provider;
use Moose;

#extends 'DevEnv';

use Data::Dumper;

has 'version' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_version'
);

sub _build_version {}

sub _version_cmp {

	my $self    = shift;
	my %args    = @_;

	my $version = $args{version};
	my $cmp     = $args{cmp} // ">=";
	my $sep     = $args{sep} // ".";
}

sub start {

	my $self   = shift;

	return 1;
}

sub stop {

	my $self   = shift;

	return 1;
}

sub version_number {

	my $self    = shift;
	my %args    = @_;

	my $version = $args{version};
	my $sep     = $args{sep} // "\.";

	my @numbers = split /\./, $version;

	my $total = 0;
	my $index = 0;
	foreach my $number ( reverse @numbers ) {
		$total += $number * 100 ** $index++;
	}

	return $total;
}

sub adjust_config {

	my $self   = shift;
	my $config = shift;

	return $config;
}

sub template_vars {

	my $self = shift;
	my $vars = shift;

	return $vars;
}

__PACKAGE__->meta->make_immutable;

1;
