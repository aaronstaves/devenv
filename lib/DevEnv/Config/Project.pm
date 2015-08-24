package DevEnv::Config::Project;
use MooseX::Singleton;

use DevEnv;

use YAML::Tiny;
use Path::Class;
use Data::Dumper;

has 'base_dir' => (
	is       => 'ro',
	isa      => 'Path::Class::Dir',
	lazy     => 1,
	builder  => '_build_base_dir'
);
sub _build_base_dir {

	my $self = shift;

	return DevEnv->new->base_dir;
}

has '_config_dirs' => (
	traits   => ['Array'],
	is       => 'ro',
	isa      => 'ArrayRef[Path::Class::Dir]',
	lazy     => 1,
	builder  => '_build_config_dirs',
	handles  => {
		all_config_dirs => "elements"
	}
);
sub _build_config_dirs {
	
	my $self = shift;

	my @dirs = ();

	if ( defined $ENV{DEVENV_CONFIG_DIR} ) {
		push @dirs, dir( $ENV{DEVENV_CONFIG_DIR} );
	}
	else {
		push @dirs, dir( $ENV{HOME}, ".devenv", "config" );
		push @dirs, dir( $self->base_dir, "config" );
		push @dirs, dir( "opt", "devenv", "config" );
	}

	return \@dirs;
}

has 'config_file' => (
	is       => 'ro',
	isa      => 'Str',
	required => 1
);

has 'config' => (
	is      => 'ro',
	isa     => 'HashRef',
	lazy    => 1,
	builder => '_build_config'
);

sub _build_config {

	my $self = shift;
	
	my $config = undef;

	foreach my $config_dir ( $self->all_config_dirs ) {

		my $config_file = $config_dir->file( $self->config_file )->stringify;

		if ( -f $config_file ) {

			my $yaml = YAML::Tiny->read( $config_file )->[0];

			# Just copy the 'vm' section
			$config->{vm} = $yaml->{vm};
	
			# Use the name a key to quick lookups
			foreach my $container ( @{$yaml->{containers}} ) {
				$config->{containers}{ $container->{name} } = $container;
			}

			last;
		}
	}

	if ( not defined $config ) {
		die "Cannot find the config file";
	}

	return $config;
}

1;
