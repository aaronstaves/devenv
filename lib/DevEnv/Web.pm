package DeveEnv::Web;
use Moose;
use MooseX::NonMoose;
extends 'HTTP::Server::Simple::CGI';

use DevEnv::Docker;

use Template;

has 'docker' => (
	is      => 'ro',
	isa     => 'DevEnv::Docker',
	lazy    => 1,
	buulder => '_build_docker'
);
sub _build_docker {

	my $self = shift;

	return DevEnv::Docker->new(
		project_config_file => $ENV{DEVENV_CONFIG_FILE},
		instance_name       => $ENV{DEVENV_NAME},
	);
}

sub handle_request {

	my $self = shift;
	my $cgi  = shift;

	my $path = $cgi->path_info();

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

	my $cgi      = $args{cgi};
	my $template = $args{template};
	my $vars     = $args{vars};

	print "HTTP/1.0 200 OK\r\n";
	print $cgi->header;

	$self->_template(
		template => $template,
		vars     => $vars
	);

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

sub _page_index {

	my $self = shift;
	my %args = @_;


}

sub _action_start {

	my $self = shift;
	my %args = @_;

	$self->docker->start();
}




no Moose;

__PACKAGE__->meta->make_immutable;
