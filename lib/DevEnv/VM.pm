package DevEnv::VM;
use Moose;

extends 'DevEnv';
with 'DevEnv::Role::Project';

use DevEnv::Exceptions;

use Module::Find;
use Module::Loaded;
use YAML::Tiny;
use Data::Dumper;

my @VM_MODULES = usesub DevEnv::VM::Module;

has '_vm' => (
	is  => 'ro',
	isa => 'DevEnv::VM::Module',
	handles => [
		qw/
			is_running
			start
			stop
			suspend
			remove
			build
			status
			connect
		/
	]
);

sub BUILD {

	my $self = shift;
	my $args = shift;

	my $class = __PACKAGE__ . "::Module::" . $self->project_config->{vm}{type};

	if ( $args->{verbose} ) {

		$self->debug( "Using class $class for VM" );
	}

	if ( not is_loaded $class  ) {

		unless ( eval "require $class" ) {
	
			DevEnv::Exception::VM->throw( "Could not load $class: $@." );
		}

		$class->import();
	}

	$self->{_vm} = $class->new( %{$args} );

	return undef;
}

sub global_status {

	my $class = shift;

    print sprintf ( "%-20s %-20s %-10s\n",
        "Instance Name",
		"Type",
        "Status"
    );

    print
        "==================== ",
        "==================== ",
        "========== ",
        "\n";

	foreach my $module ( @VM_MODULES ) {

		my ( $module_name ) = $module =~ m/([^:]+)$/;

		my $vms = $module->get_global_status();

		foreach my $name ( sort keys %{$vms} ) {

			print sprintf ( "%-20s %-20s %-10s\n",
				$name,
				$module_name,
				$vms->{$name}{state}
			)
		}
	}

	return undef;
}

sub global_stop {

	my $class = shift;
	my %args  = @_;

	my @instance_stopped = ();

	foreach my $module ( @VM_MODULES ) {

		my ( $module_name ) = $module =~ m/([^:]+)$/;

		my $vms = $module->get_global_status();

		foreach my $name ( sort keys %{$vms} ) {

			my $vm = __PACKAGE__->new(
				instance_name       => $name,
				verbose             => $args{verbose}
			);

			$vm->debug( "$module -> $name" );

			# If it's not running, then don't stop it
			next if ( not $vm->is_running );

			$vm->debug( " * stopping" );

			push @instance_stopped, $name;

			$vm->stop();
		}
	}

    my $yaml = YAML::Tiny->new( @instance_stopped );
    $yaml->write( sprintf( "%s/.devenv/global_stop.yml", $ENV{HOME} ) );
}

__PACKAGE__->meta->make_immutable;

1;
