package DevEnv::Role::Project;
use Moose::Role;

use DevEnv::Config::Project;

use Path::Class;
use File::Spec;

has 'config' => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_config'
);
sub _build_config {

    my $self = shift;

    return DevEnv::Config::Project->initialize(
        config_file => $self->config_file,
    )->config;
}

has 'config_file' => (
	is       => 'rw',
	isa      => 'Str'
);

has 'instance_name' => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
	trigger  => sub {
		my $self          = shift;
		my $instance_name = shift;

		$instance_name =~ s/\s/_/g;
		$instance_name =~ s/\//-/g;

		$self->{instance_name} = $instance_name;
	}
);

1;
