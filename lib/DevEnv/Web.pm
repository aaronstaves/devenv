package DeveEnv::Web;
use Moose;
use MooseX::NonMoose;
extends 'HTTP::Server::Simple::CGI';

use DevEnv::Docker;
use DevEnv::Exceptions;

use Template;
use Try::Tiny;
use JSON::XS;

has 'docker' => (
	is      => 'ro',
	isa     => 'DevEnv::Docker',
	lazy    => 1,
	builder => '_build_docker'
);
sub _build_docker {

	my $self = shift;

	return DevEnv::Docker->new(
		project_config_file => $self->config_file,
		instance_name       => $self->instance_name,
		port_offset         => $self->port_offset
	);
}

has 'config_file' => (
	isa     => 'Str',
	is      => 'rw',
	default => sub {
		return $ENV{DEVENV_CONFIG_FILE}
	}
);

has 'instance_name' => (
	isa     => 'Str',
	is      => 'rw',
	default => sub {
		return $ENV{DEVENV_NAME}
	}
);

has 'port_offset' => (
    isa     => 'Int',
    is      => 'rw',
	default => sub {
		return $ENV{DEVENV_PORT_OFFSET}
	}
);

sub handle_request {

	my $self = shift;
	my $cgi  = shift;

	my $path = $cgi->path_info();

	my ( $action ) = $path =~ m/^([^\/]+)/;

	if ( $action =~ m/^(action|page|file)/ and $action->can( "_$action" ) ) {
		$self->( "_$action" )( cgi => $cgi, path => $path );
	}
	else {
		$self->_error(
			status  => 404, 
			error   => "Not Found",
			message => "Could not find an action for $path"
		);
	}

	return undef;
}

sub _template {

	my $self = shift;
	my %args = @_;

	my $vars     = $args{vars} || {};
	my $template = $args{template};

	my $include_path = $self->base_dir->subdir( "template", "web" )->stringify();

	my $tt = Template->new({
		INCLUDE_PATH => $include_path,
		EVAL_PERL    => 1,
	}) or die "$Template::ERROR\n";

	my $output = '';
	$tt->process( $template, $vars, \$output) or die "Cannot generate $template";

	print $output;
}

sub _ok {

	my $self = shift;
	my %args = @_;

	my $cgi          = $args{cgi};
	my $template     = $args{template};
	my $vars         = $args{vars};
	my $content_type = $args{content_type} // "text/html";
	my $content      = $args{content};

	print "HTTP/1.0 200 OK\r\n";
	print $cgi->header;
	print $cgi->header( $content_type );

	if ( defined $template ) {

		$self->_template(
			template => $template,
			vars     => $vars
		);
	}
	else {
		print $content;
	}

	return undef;
}

sub _error {

	my $self = shift;
	my %args = @_;

	my $cgi     = $args{cgi};
	my $status  = $args{status} || 500;
	my $error   = $args{error};
	my $message = $args{message};

	print "HTTP/1.0 $status Error\r\n";
	print $cgi->header;

	$self->_template(
		template => "error.tt",
		vars     => {
			status  => $status,
			title   => $error,
			error   => $error,
			message => $message
		}
	);

	return undef;
}

sub _file {

	my $self = shift;
	my %args = @_;

	my $path = $args{path};

	my ( $file ) = $path =~ m/files\/(.*)$/;

	open my $fh, sprintf ( "%s/files/%s", $self->docker->base_dir, $file );
	while ( my $data = <$fh> ) {
		print $data;
	}
	close $fh;
}

sub _page_index {

	my $self = shift;
	my %args = @_;

}

sub _action_start {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	try {

		$self->docker->start(
			containers => [ $cgi->param('containers') ]
		);

		$self->_ok(
			cgi          => $cgi,
			content_type => "applitcation/json",
			content      => JSON::XS->new->utf8->pretty->encode( {} )
		);
	}
	catch_norethrow {

		$self->_error(
			cgi     => $cgi,
			error   => "$_",
			message => "Error"
		);
	};
}

no Moose;

__PACKAGE__->meta->make_immutable;
