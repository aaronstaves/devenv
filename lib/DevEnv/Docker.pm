package DevEnv::Docker;
use Moose;

extends 'DevEnv';
with 'DevEnv::Role::Project';

use DevEnv::Docker::Control;

use Data::Dumper;

has 'control' => (
	is       => 'ro',
	isa      => 'DevEnv::Docker::Control',	
	lazy     => 1,
	builder  => '_build_control'
);
sub _build_control { return DevEnv::Docker::Control->new() }


sub _container_order {

	my $self = shift;

	my $scoreboard = undef;

	foreach my $container_name ( keys %{$self->config->{containers}} ) {

		$scoreboard->{ $container_name } //= 0;
	
		my $container_config = $self->config->{containers}{ $container_name };

		# Always start the data container first
		if ( $container_config->{type} eq "data" ) {
			$scoreboard->{ $container_name } += 1_000_000;
		}

		# Increase the score of the container that is link required for this one
		if ( defined $container_config->{link} and ref $container_config->{link} eq "ARRAY" ) {
			foreach my $link ( @{$container_config->{link}} ) {
				$scoreboard->{ $link }++;
			}
		}
	}

	my @containers = sort { $scoreboard->{$b} <=> $scoreboard->{$a} } keys %{$scoreboard};

	return wantarray ? @containers : \@containers;
}

sub _instance_name {

	my $self           = shift;
	my $container_name = shift;

	if ( defined $self->instance_name ) {
		$container_name = sprintf( "%s_%s", $self->instance_name, $container_name );
	}

	return $container_name;
}

sub _image_name {

	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};
	my $config = $self->config->{containers}{ $container_name };

	return "devenv/" . $config->{image}{name};
}

sub _image_name_version {

	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};
	my $images  = $self->control->images();

	my $name    = $self->_image_name( container_name => $container_name );
	my $version = $images->{ $self->_image_name( container_name => $container_name ) }{tag};

	return "$name:$version";
}

sub _env {

	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};

	my ( $gid ) = split /\s/, $(;

	my $env_hashref = {
		HOST_USER_HOME => $ENV{HOME},
		HOST_USER_NAME => $ENV{USER},
		HOST_USER_UID  => $<,
		HOST_USER_GID  => $gid,
	};

	my $config = $self->config->{containers}{ $container_name };

	if ( defined $config->{envs} ) {
		
		foreach my $env ( @{$config->{envs}} ) {
			$env_hashref->{ "DEVENV_" . $env->{name} } = $env->{value};
		}
	}

	return $env_hashref;
}

sub _env_string {

	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};


	my $env_hashref = $self->_env( container_name => $container_name );

	my @envs = ();
	foreach my $name ( sort keys %{$env_hashref} ) {
		
		my $value = $env_hashref->{$name};
		$value =~ s/"/\\"/g;

		push @envs, "$name=\"$value\"";
	}

	return wantarray ? @envs : \@envs;
};

sub start {

	my $self = shift;
	my %args = @_;

	if ( $args{foreground} and not defined $args{command} ) {
		$args{command} = "/bin/bash";
	}

	# Get the process list of the containers.
	my $ps     = $self->control->ps;
	my $images = $self->control->images;
	
	my @container_order = $self->_container_order();

	# Get the order that the containers should be started
	while ( my $container_name = shift @container_order ) {

		my $config = $self->config->{containers}{ $container_name };

		my $is_last_container = ( 
			not scalar @container_order
		or 
			( defined $args{start_until} and $args{start_until} eq $container_name )
		)?1:0;

		print STDERR "Last Container = $is_last_container\n";

		my $instance_name = $self->_instance_name( $container_name );

		# If the container doesn't exists, try to build it
		if ( not defined $images->{$container_name} ) {
			# TODO: Build container
		}

		my @command = ();

		# If we found it, it needs to be started
		if ( defined $ps->{ $instance_name } ) {

			my $status = $ps->{ $instance_name }{status};

			if ( $status =~ m/^Exit/ ) {
				push @command, "start";
			}
			elsif ( $status =~ m/^Up/  ) {
				push @command, "restart";
			}
			else {
				print STDERR "Unknown status $status, skipping containter start\n";
				next;
			}

			push @command, $ps->{ $instance_name }{container_id};
		}
		else {
			push @command, "run";
			push @command, "--name";
			push @command, $instance_name;
			push @command, "-h";
			push @command, $instance_name;

			if ( $args{foreground} and $is_last_container ) {
				push @command, "-i";
				push @command, "-t";
				push @command, "--rm";
			}
			else {
				push @command, "-d";
			}

			if ( defined $config->{links} ) {
		
				foreach my $link ( @{$config->{links}} ) {

					if ( $self->config->{ $link }{type} ne "data" ) {
						push @command, "--link";
						push @command, $self->_instance_name( $link );
					}

					push @command, "--volumes-from";
					push @command, $self->_instance_name( $link );
				}
			}

			foreach my $env ( $self->_env_string( container_name => $container_name ) ) {
				push @command, "-e";
				push @command, $env;
			}

			push @command, $images->{ $self->_image_name( container_name => $container_name ) }{image_id};

			if ( defined $args{command} ) {
				push @command, $args{command};
			}
		}
	
		$self->control->command( command => \@command );
	}
}

sub build {

	my $self = shift;
	my %args = @_;


	



}

__PACKAGE__->meta->make_immutable;

1;
