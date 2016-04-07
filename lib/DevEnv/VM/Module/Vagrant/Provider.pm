package DevEnv::VM::Module::Vagrant::Provider;
use Moose;

extends 'DevEnv';

sub _version_cmp {

	my $self    = shift;
	my %args    = @_;

	my $version = $args{version};
	my $cmp     = $args{cmp} // ">=";
	my $sep     = $args{sep} // ".";
}

sub adjust_config {

	my $self = shift;
	my %args = @_;

	my $config = $args{config};

	return $config;
}

sub template_vars {

	my $self = shift;


	return {};
}

__PACKAGE__->meta->make_immutable;

1;
