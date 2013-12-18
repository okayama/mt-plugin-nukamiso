package Nukamiso::Plugin;
use strict;

#use lib qw( lib/MT/Template/Tags );
use MT::Template::Tags::Filters;

sub initializer {
    require Nukamiso::Patch;
    1;
}

# sub _cb_tp_header {
#     my ( $cb, $app, $param ) = @_;
#     $param->{ html_head } ||= '';
#     $param->{ html_head } .=<<'CSS';
# <style type="text/css">
# #main {
#     position: relative;
# }
# #display-options {
#     position: absolute;
#     display:block;
#     top: 0;
#     right: 0;
#     background: #fff;
#     z-index: 499;
# }
# #display-options-detail {
#     border: 3px solid #c0c6c9;
# }
# </style>
# CSS
#     use Data::Dumper;
#     MT->log( 'param: ' . Dumper $param );
# }

sub _cb_cms_pre_run {
    my $app = MT->instance();
    $app->config( 'AutoSaveFrequency', 0 );
}

sub _cb_ts_edit_template {
    my ( $cb, $app, $tmpl ) = @_;
    $$tmpl =~ s/(?<!function\s)documentTags.*?\;//g;
}

sub _cb_tp_edit_template {
    my ( $cb, $app, $param, $tmpl ) = @_;
    return 1 unless $app->param( 'id' );
    my $template = MT->model( 'template' )->load( $app->param( 'id' ) );
    return 1 unless $template;
    return 1 unless $template->type eq 'index';
    if ( my $pointer_field = $tmpl->getElementById( 'template-body' ) ) {
        my $nodeset = $tmpl->createElement( 'app:setting',
                                            { id => 'file-text',
                                              label => '',
                                              label_class => 'top-label',
                                            }
                                          );
        my $blog = $app->blog;
        my $fmgr = $blog->file_mgr;
        my $file_path = File::Spec->catfile( $blog->site_path, $template->outfile );
        if ( $fmgr->exists( $file_path ) ) {
            $param->{ file_text } = $fmgr->get_data( $file_path );
        }
        my $innerHTML =<<'MTML';
<__trans_section component="Nukamiso">
<div id="file-text">
  <div id="file-text-header" class="line">
    <div class="file-text-toggle">
      <a href="javascript:void(0);" class="icon-left icon-spinner" onclick="return toggleActive('file-text');"><__trans phrase="File text"></a>
    </div>
  </div>
  <div id="template-options-content">
    <textarea readonly="readonly" class="text high"><mt:var name="file_text" escape="html"></textarea>
  </div>
</div>
<style type="text/css">
#file-text-field {
  margin-bottom: 5px;
}
#file-text-header {
    overflow: hidden;
}
#file-text {
    background-color: #DCDDDD;
    border-radius: 3px;
    margin-bottom: 8px;
    padding: 1px 10px;
    position: relative;
}
.file-text-toggle {
    float: left;
    font-weight: bold;
    height: 30px;
    line-height: 30px;
    margin: 0;
}
.file-text-toggle a {
    color: #1A1A1A;
}
#template-options-content {
    padding-bottom: 10px;
}
</style>
</__trans_section>
MTML
        $nodeset->innerHTML( $innerHTML );
        $tmpl->insertAfter( $nodeset, $pointer_field );
    }
}

sub _cb_ts_header {
    my ( $cb, $app, $tmpl ) = @_;
    if ( $app->mode eq 'list' && $app->param( '_type' ) eq 'log' ) {
        my $insert = <<CSS;
<style type="text/css">
.col .log-metadata pre {
    white-space: pre;
}
</style>
CSS
        $$tmpl =~ s!(</head>)!$insert$1!;
    }
    my $display_option_css =<<'CSS';
<mt:setvarblock name="html_head" append="1">
<style type="text/css">
#main {
    position: relative;
}
#display-options {
    position: absolute;
    display:block;
    top: 0;
    right: 0;
    background: #fff;
    z-index: 499;
    background-color: transparent;
}
.display-options {
    margin: 0;
}
#display-options-detail {
    border: 3px solid #c0c6c9;
    background-color: #FFF;
}
</style>
</mt:setvarblock>
CSS
    $$tmpl = $display_option_css . $$tmpl;
    my $system_log =<<'MTML';
<mt:if name="can_view_log">
<li id="systemlog" class="systemlog"><a href="<$mt:var name="mt_url"$>?__mode=list&amp;_type=log"><__trans phrase="System Activity Log"></a></li>
</mt:if>
MTML
    $$tmpl =~ s/(\Q<li id="help"\E)/$system_log$1/;
    1;
}

sub _cb_list_template_param_log {
    my ( $cb, $app, $param, $tmpl ) = @_;
    $param->{ default_sort_key } = 'id';
    1;
}

sub _cb_take_down {
    my $app = MT->instance();
    if ( $app->config->ResponseContentLogging ) {
        return 1 if $app->{ redirect };
        return 1 if $app->{ login_again };
        return 1 if $app->{ no_print_body };
        my $body = $app->response_content();
        if ( ref( $body ) && ( $body->isa( 'MT::Template' ) ) ) {
            my $out = $app->build_page( $body );
            unless ( defined $out ) {
                MT->log( $body->errstr );
                return;
            }
            $body = $out;
        }
        MT->log( 'response_content: ' . $body );
    }
    1;
}

sub _cb_log_pre_save {
    my ( $cb, $obj ) = @_;
    return 1 if $obj->metadata;
    if ( my $msg = $obj->message ) {
        my $excerpt = MT::Template::Tags::Filters::_fltr_trim_to( $msg, 200 . '+...' );
        unless ( $msg eq $excerpt ) {
            $obj->message( $excerpt );
            $obj->metadata( $msg );
        }
    }
    1;
}

sub _cb_log_post_save {
    my ( $cb, $obj ) = @_;
    return 1 unless MT->config->DebugMode;
    if ( MT->config->ShowErrorsOnly ) {
        return 1 unless $obj->level eq MT::Log::ERROR();
    }
    my $r = MT::Request->instance();
    my $error_logs = $r->cache( LOGS_KEY() );
    $error_logs ||= [];
    push( @$error_logs, $obj );
    $r->cache( LOGS_KEY(), $error_logs );
    1;
}

sub _cb_ts_footer {
    my ( $cb, $app, $tmpl ) = @_;
# use Data::Dumper;
# MT->log( { level => MT::Log::ERROR(), message => MT::Util::encode_html( $$tmpl ) } );
# MT->log( { level => MT::Log::ERROR(), message => '1' } );
# MT->log( { level => MT::Log::ERROR(), message => '2' } );
# MT->log( { level => MT::Log::ERROR(), message => '3' } );
# MT->log( { level => MT::Log::ERROR(), message => '4' } );
# MT->log( { level => MT::Log::ERROR(), message => '5' } );
# MT->log( { level => MT::Log::ERROR(), message => '6' } );
# MT->log( { level => MT::Log::ERROR(), message => '7' } );
# MT->log( { level => MT::Log::ERROR(), message => '8' } );
# MT->log( { level => MT::Log::ERROR(), message => '9' } );
# MT->log( { level => MT::Log::ERROR(), message => '10' } );
# MT->log( { level => MT::Log::ERROR(), message => '11' } );
# MT->log( { level => MT::Log::ERROR(), message => '12' } );
    return 1 unless MT->config->DebugMode;
    my $r = MT::Request->instance();
    my $error_logs = $r->cache( LOGS_KEY() );
    unless ( $error_logs ) {
        if ( MT->config->ShowRecentLogs ) {
            $error_logs = [ MT->model( 'log' )->load( ( MT->config->ShowErrorsOnly ? { class => MT::Log::ERROR(), } : undef ),
                                                      { 'sort' => 'created_on',
                                                        direction => 'descend',
                                                        ( MT->config->ShowErrorsOnly ? () : ( no_class => 1, ) ),
                                                      },
                                                    )
                          ];
        }
    }
    return 1 unless $error_logs;
    return 1 unless @$error_logs;
    my $body = '';
    my $counter = 0;
    if ( $error_logs ) {
        $body .= '<p id="draggable-logs-list-headline"><strong>LOG</strong></p>';
        $body .= '<div id="recent-error-logs-wrapper"><ul id="recent-error-logs">';
        require MT::Template::Tags::Filters;
        my @error_logs = reverse( @$error_logs );
        while ( my $log = shift( @error_logs ) ) {
            my $message = Encode::decode_utf8( MT::I18N::utf8_off( $log->message ) );
            my $excerpt = MT::Template::Tags::Filters::_fltr_trim_to( $message, 200 . '+...' );
            $body .= '<li>' . $excerpt . '</li>';
            $counter++;
            last if $counter == LOGS_LIMIT();
        }
        if ( $counter > LOGS_LIMIT() ) {
            $body .= '<li id="draggable-logs-list-more">..and more.</li>';
        }
        $body .= '</ul>';
    }
    my $url_list_log = $app->base . $app->uri( mode => 'list',
                                               args => {
                                                    _type => 'log',
                                               }
                                             );
    $body .= '<div id="draggable-logs-list-view-log"><a href="' . $url_list_log . '" target="_blank">all logs</a></div></div>';
    my $insert =<<HTML;
<script>
jQuery( function() {
    jQuery( '#draggable-logs-list' ).draggable();
} );
</script>

<style>
#draggable-logs-list {
    padding: 0;
    width: 400px;
    margin: 0;
    border: 1px solid #CCCCCC;
    position: absolute;
    top: 1px;
    right: 1px;
    z-index: 9999;
}
#draggable-logs-list #logs {
    position: relative;
}
#draggable-logs-list #logs li {
    list-style-type: square;
    margin-left: 1em;
}
#draggable-logs-list-headline {
    padding: 5px 0 3px 0;
    margin-bottom: 0px;
    background: #FFFFCC;
    border-bottom: 1px solid #DDDDDD;
    text-align: center;
    font-size: 110%;
    font-weight: normal;
}
#recent-error-logs-wrapper {
    background: #EEEEEE;
    padding: 5px 5px 2.1em 5px;
}
#recent-error-logs {
    padding: 5px 5px 0px 10px;
    background: #FFF;
    border: 1px solid #CCC;
}
#close-draggable-logs-list {
    position: absolute;
    bottom: 3px;
    left: 5px;
}
#draggable-logs-list-more {
    padding: 0px 5px 0px 0px;
    margin-bottom: 5px;
    text-align: right;
    list-style-type: none !important;
}
#draggable-logs-list-view-log {
    position: absolute;
    bottom: 3px;
    right: 5px;
}
</style>

<div id="draggable-logs-list">
    <div id="logs">
        <a href="#" id="close-draggable-logs-list" onclick="javascript:getByID( 'draggable-logs-list' ).style.display='none';">close</a>
        $body
    </div>
</div>
HTML
    $$tmpl =~ s!(</body>)!$insert$1!;
    1;
}

sub LOGS_KEY() { 'Nukamiso-LOGS' };
sub LOGS_LIMIT() { 3 };


1;
