package DevEnv::VM;
use Moose;

extends 'DevEnv';
with 'DevEnv::Role::Project';

use DevEnv::Exceptions;

use Module::Find;
use Module::Loaded;

my @VM_MODULES = usesub DevEnv::VM::Module;

has '_vm' => (
	is  => 'ro',
	isa => 'DevEnv::VM::Module',
	handles => [
		qw/
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

	foreach my $module ( @VM_MODULES ) {

		my ( $module_name ) = $module =~ m/([^:]+)$/;

		my $vms = $module->get_global_status();

		foreach my $name ( sort keys %{$vms} ) {

			__PACKAGE__->new(
				instance_name       => $name,
				verbose             => $args{verbose}
			)->stop();
		}
	}
}

__PACKAGE__->meta->make_immutable;

1;
