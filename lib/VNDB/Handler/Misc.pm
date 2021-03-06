
package VNDB::Handler::Misc;


use strict;
use warnings;
use TUWF ':html', ':xml', 'xml_escape', 'uri_escape';
use VNDB::Func;
use POSIX 'strftime';


TUWF::register(
  qr{},                              \&homepage,
  qr{(?:([upvrcs])([1-9]\d*)/)?hist},\&history,
  qr{d([1-9]\d*)},                   \&docpage,
  qr{nospam},                        \&nospam,
  qr{xml/prefs\.xml},                \&prefs,
  qr{opensearch\.xml},               \&opensearch,

  # redirects for old URLs
  qr{u([1-9]\d*)/tags}, sub { $_[0]->resRedirect("/g/links?u=$_[1]", 'perm') },
  qr{(.*[^/]+)/+}, sub { $_[0]->resRedirect("/$_[1]", 'perm') },
  qr{([pv])},      sub { $_[0]->resRedirect("/$_[1]/all", 'perm') },
  qr{v/search},    sub { $_[0]->resRedirect("/v/all?q=".uri_escape($_[0]->reqGet('q')||''), 'perm') },
  qr{notes},       sub { $_[0]->resRedirect('/d8', 'perm') },
  qr{faq},         sub { $_[0]->resRedirect('/d6', 'perm') },
  qr{v([1-9]\d*)/(?:stats|scr)},
    sub { $_[0]->resRedirect("/v$_[1]", 'perm') },
  qr{u/list(/[a-z0]|/all)?},
    sub { my $l = defined $_[1] ? $_[1] : '/all'; $_[0]->resRedirect("/u$l", 'perm') },
  qr{d([1-9]\d*)\.([1-9]\d*)},
    sub { $_[0]->resRedirect("/d$_[1]#$_[2]", 'perm') }
);


sub homepage {
  my $self = shift;

  my $title = 'The Visual Novel Database';
  my $desc = 'VNDB.org strives to be a comprehensive database for information about visual novels.';

  my $metadata = {
    'og:type' => 'website',
    'og:title' => $title,
    'og:description' => $desc,
  };

  $self->htmlHeader(title => $title, feeds => [ keys %{$self->{atom_feeds}} ], metadata => $metadata);

  div class => 'mainbox';
   h1 $title;
   p class => 'description';
    txt $desc;
    br;
    txt 'This website is built as a wiki, meaning that anyone can freely add'
      .' and contribute information to the database, allowing us to create the'
      .' largest, most accurate and most up-to-date visual novel database on the web.';
   end;

   # with filters applied it's signifcantly slower, so special-code the situations with and without filters
   my @vns;
   if($self->authPref('filter_vn')) {
     my $r = $self->filFetchDB(vn => undef, undef, {hasshot => 1, results => 4, sort => 'rand'});
     @vns = map $_->{id}, @$r;
   }
   my $scr = $self->dbScreenshotRandom(@vns);
   p class => 'screenshots';
    for (@$scr) {
      my($w, $h) = imgsize($_->{width}, $_->{height}, @{$self->{scr_size}});
      a href => "/v$_->{vid}", title => $_->{title};
       img src => imgurl(st => $_->{scr}), alt => $_->{title}, width => $w, height => $h;
      end;
    }
   end;
  end 'div';

  table class => 'mainbox threelayout';
   Tr;

    # Recent changes
    td;
     h1;
      a href => '/hist', 'Recent Changes'; txt ' ';
      a href => '/feeds/changes.atom'; cssicon 'feed', 'Atom Feed'; end;
     end;
     my $changes = $self->dbRevisionGet(results => 10, auto => 1);
     ul;
      for (@$changes) {
        li;
         txt "$_->{type}:";
         a href => "/$_->{type}$_->{itemid}.$_->{rev}", title => $_->{ioriginal}||$_->{ititle}, shorten $_->{ititle}, 33;
         lit " by ".fmtuser($_);
        end;
      }
     end;
    end 'td';

    # Announcements
    td;
     my $an = $self->dbThreadGet(type => 'an', sort => 'id', reverse => 1, results => 2);
     h1;
      a href => '/t/an', 'Announcements'; txt ' ';
      a href => '/feeds/announcements.atom'; cssicon 'feed', 'Atom Feed'; end;
     end;
     for (@$an) {
       my $post = $self->dbPostGet(tid => $_->{id}, num => 1)->[0];
       h2;
        a href => "/t$_->{id}", $_->{title};
       end;
       p;
        lit bb2html $post->{msg}, 150;
       end;
     }
    end 'td';

    # Recent posts
    td;
     h1;
      a href => '/t/all', 'Recent Posts'; txt ' ';
      a href => '/feeds/posts.atom'; cssicon 'feed', 'Atom Feed'; end;
     end;
     my $posts = $self->dbThreadGet(what => 'lastpost boardtitles', results => 10, sort => 'lastpost', reverse => 1, notusers => 1);
     ul;
      for (@$posts) {
        my $boards = join ', ', map $self->{discussion_boards}{$_->{type}}.($_->{iid}?' > '.$_->{title}:''), @{$_->{boards}};
        li;
         txt fmtage($_->{ldate}).' ';
         a href => "/t$_->{id}.$_->{count}", title => "Posted in $boards", shorten $_->{title}, 25;
         lit ' by '.fmtuser($_->{luid}, $_->{lusername});
        end;
      }
     end;
    end 'td';

   end 'tr';
   Tr;

    # Random visual novels
    td;
     h1;
      a href => '/v/rand', 'Random visual novels';
     end;
     my $random = $self->filFetchDB(vn => undef, undef, {results => 10, sort => 'rand'});
     ul;
      for (@$random) {
        li;
         a href => "/v$_->{id}", title => $_->{original}||$_->{title}, shorten $_->{title}, 40;
        end;
      }
     end;
    end 'td';

    # Upcoming releases
    td;
     h1;
      a href => '/r?fil=released-0;o=a;s=released', 'Upcoming releases';
     end;
     my $upcoming = $self->filFetchDB(release => undef, undef, {results => 10, released => 0, what => 'platforms'});
     ul;
      for (@$upcoming) {
        li;
         lit fmtdatestr $_->{released};
         txt ' ';
         cssicon $_, $self->{platforms}{$_} for (@{$_->{platforms}});
         cssicon "lang $_", $self->{languages}{$_} for (@{$_->{languages}});
         txt ' ';
         a href => "/r$_->{id}", title => $_->{original}||$_->{title}, shorten $_->{title}, 30;
        end;
      }
     end;
    end 'td';

    # Just released
    td;
     h1;
      a href => '/r?fil=released-1;o=d;s=released', 'Just released';
     end;
     my $justrel = $self->filFetchDB(release => undef, undef, {results => 10, sort => 'released', reverse => 1, released => 1, what => 'platforms'});
     ul;
      for (@$justrel) {
        li;
         lit fmtdatestr $_->{released};
         txt ' ';
         cssicon $_, $self->{platforms}{$_} for (@{$_->{platforms}});
         cssicon "lang $_", $self->{languages}{$_} for (@{$_->{languages}});
         txt ' ';
         a href => "/r$_->{id}", title => $_->{original}||$_->{title}, shorten $_->{title}, 30;
        end;
      }
     end;
    end 'td';

   end 'tr';
  end 'table';

  $self->htmlFooter;
}


sub history {
  my($self, $type, $id) = @_;
  $type ||= '';
  $id ||= 0;

  my $f = $self->formValidate(
    { get => 'p', required => 0, default => 1, template => 'page' },
    { get => 'm', required => 0, default => !$type, enum => [ 0, 1 ] },
    { get => 'h', required => 0, default => 0, enum => [ -1..1 ] },
    { get => 't', required => 0, default => '', enum => [qw|v r p c s a|] },
    { get => 'e', required => 0, default => 0, enum => [ -1..1 ] },
    { get => 'r', required => 0, default => 0, enum => [ 0, 1 ] },
  );
  return $self->resNotFound if $f->{_err};

  # get item object and title
  my $obj = $type eq 'u' ? $self->dbUserGet(uid => $id, what => 'hide_list')->[0] :
            $type eq 'p' ? $self->dbProducerGet(id => $id)->[0] :
            $type eq 'r' ? $self->dbReleaseGet(id => $id)->[0] :
            $type eq 'c' ? $self->dbCharGet(id => $id)->[0] :
            $type eq 's' ? $self->dbStaffGet(id => $id)->[0] :
            $type eq 'v' ? $self->dbVNGet(id => $id)->[0] : undef;
  return $self->resNotFound if $type && !$obj->{id};
  my $title = $type ? 'Edit history of '.($obj->{title} || $obj->{name} || $obj->{username}) : 'Recent changes';

  # get the edit history
  my($list, $np) = $self->dbRevisionGet(
    $type && $type ne 'u' ? ( type => $type, itemid => $id ) : (),
    $type eq 'u' ? ( uid => $id ) : (),
    $f->{t} ? ( type => $f->{t} eq 'a' ? [qw|v r p s|] : $f->{t} ) : (),
    page => $f->{p},
    results => 50,
    auto => $f->{m},
    hidden => $type && $type ne 'u' ? 0 : $f->{h},
    edit => $f->{e},
    releases => $f->{r},
  );

  $self->htmlHeader(title => $title, noindex => 1, feeds => [ 'changes' ]);
  $self->htmlMainTabs($type, $obj, 'hist') if $type;

  # url generator
  my $u = sub {
    my($n, $v) = @_;
    $n ||= '';
    local $_ = ($type ? "/$type$id" : '').'/hist';
    $_ .= '?m='.($n eq 'm' ? $v : $f->{m});
    $_ .= ';h='.($n eq 'h' ? $v : $f->{h});
    $_ .= ';t='.($n eq 't' ? $v : $f->{t});
    $_ .= ';e='.($n eq 'e' ? $v : $f->{e});
    $_ .= ';r='.($n eq 'r' ? $v : $f->{r});
  };

  # filters
  div class => 'mainbox';
   h1 $title;
   if($type ne 'u') {
     p class => 'browseopts';
      a !$f->{m} ? (class => 'optselected') : (), href => $u->(m => 0), 'Show automated edits';
      a  $f->{m} ? (class => 'optselected') : (), href => $u->(m => 1), 'Hide automated edits';
     end;
   }
   if(!$type || $type eq 'u') {
     if($self->authCan('dbmod')) {
       p class => 'browseopts';
        a $f->{h} == 1  ? (class => 'optselected') : (), href => $u->(h =>  1), 'Hide deleted items';
        a $f->{h} == -1 ? (class => 'optselected') : (), href => $u->(h => -1), 'Show deleted items';
       end;
     }
     p class => 'browseopts';
      a !$f->{t}        ? (class => 'optselected') : (), href => $u->(t => ''),  'Show all items';
      a  $f->{t} eq 'v' ? (class => 'optselected') : (), href => $u->(t => 'v'), 'Only visual novels';
      a  $f->{t} eq 'r' ? (class => 'optselected') : (), href => $u->(t => 'r'), 'Only releases';
      a  $f->{t} eq 'p' ? (class => 'optselected') : (), href => $u->(t => 'p'), 'Only producers';
      a  $f->{t} eq 's' ? (class => 'optselected') : (), href => $u->(t => 's'), 'Only staff';
      a  $f->{t} eq 'c' ? (class => 'optselected') : (), href => $u->(t => 'c'), 'Only characters';
      a  $f->{t} eq 'a' ? (class => 'optselected') : (), href => $u->(t => 'a'), 'All except characters';
     end;
     p class => 'browseopts';
      a !$f->{e}       ? (class => 'optselected') : (), href => $u->(e =>  0), 'Show all changes';
      a  $f->{e} == 1  ? (class => 'optselected') : (), href => $u->(e =>  1), 'Only edits';
      a  $f->{e} == -1 ? (class => 'optselected') : (), href => $u->(e => -1), 'Only newly created pages';
     end;
   }
   if($type eq 'v') {
     p class => 'browseopts';
      a !$f->{r} ? (class => 'optselected') : (), href => $u->(r => 0), 'Exclude edits of releases';
      a $f->{r}  ? (class => 'optselected') : (), href => $u->(r => 1), 'Include edits of releases';
     end;
   }
  end 'div';

  $self->htmlBrowseHist($list, $f, $np, $u->());
  $self->htmlFooter;
}


sub docpage {
  my($self, $did) = @_;

  my $f = sprintf('%s/data/docs/%d', $VNDB::ROOT, $did);
  my $F;
  open($F, '<:utf8', $f) or return $self->resNotFound;
  my @c = <$F>;
  close $F;

  (my $title = shift @c) =~ s/^:TITLE://;
  chomp $title;

  my($sec, $subsec) = (0,0);
  for (@c) {
    s{^:SUB:(.+)\r?\n$}{
      $sec++;
      $subsec = 0;
      qq|<h3><a href="#$sec" name="$sec">$sec. $1</a></h3>\n|
    }e;
    s{^:SUBSUB:(.+)\r?\n$}{
      $subsec++;
      qq|<h4><a href="#$sec.$subsec" name="$sec.$subsec">$sec.$subsec. $1</a></h4>\n|
    }e;
    s{^:INC:(.+)\r?\n$}{
      $f = sprintf('%s/data/docs/%s', $VNDB::ROOT, $1);
      open($F, '<:utf8', $f) or die $!;
      my $ii = join('', <$F>);
      close $F;
      $ii;
    }e;
    s{^:MODERATORS:$}{
      my $l = $self->dbUserGet(results => 100, sort => 'id', notperm => $self->{default_perm}, what => 'extended');
      my $admin = 0;
      $admin |= $_ for values %{$self->{permissions}};
      '<dl>'.join('', map {
        my $u = $_;
        my $p = $u->{perm} >= $admin ? 'admin' : join ', ', sort map +($u->{perm} &~ $self->{default_perm}) & $self->{permissions}{$_} ? $_ : (), keys %{$self->{permissions}};
        $p ? sprintf('<dt><a href="/u%d">%s</a></dt><dd>%s</dd>', $_->{id}, $_->{username}, $p) : ()
      } @$l).'</dl>';
    }e;
    s{^:SKINCONTRIB:$}{
      my %users;
      push @{$users{ $self->{skins}{$_}[1] }}, [ $_, $self->{skins}{$_}[0] ]
        for sort { $self->{skins}{$a}[0] cmp $self->{skins}{$b}[0] } keys %{$self->{skins}};
      my $u = $self->dbUserGet(uid => [ keys %users ]);
      '<dl>'.join('', map sprintf('<dt><a href="/u%d">%s</a></dt><dd>%s</dd>',
        $_->{id}, $_->{username}, join(', ', map sprintf('<a href="?skin=%s">%s</a>', $_->[0], $_->[1]), @{$users{$_->{id}}})
      ), @$u).'</dl>';
    }e;
  }

  $self->htmlHeader(title => $title);
  div class => 'mainbox';
   h1 $title;
   div class => 'docs';
    lit join '', @c;
   end;
  end;
  $self->htmlFooter;
}


sub nospam {
  my $self = shift;
  $self->htmlHeader(title => 'Could not send form', noindex => 1);

  div class => 'mainbox';
   h1 'Could not send form';
   div class => 'warning';
    h2 'Error';
    p 'The form could not be sent, please make sure you have Javascript enabled in your browser.';
   end;
  end;

  $self->htmlFooter;
}


sub prefs {
  my $self = shift;
  return if !$self->authCheckCode;
  return $self->resNotFound if !$self->authInfo->{id};
  my $f = $self->formValidate(
    { get => 'key',   enum => [qw|filter_vn filter_release|] },
    { get => 'value', required => 0, maxlength => 2000 },
  );
  return $self->resNotFound if $f->{_err};
  $self->authPref($f->{key}, $f->{value});

  # doesn't really matter what we return, as long as it's XML
  $self->resHeader('Content-type' => 'text/xml');
  xml;
  tag 'done', '';
}


sub opensearch {
  my $self = shift;
  my $h = $self->reqBaseURI();
  $self->resHeader('Content-Type' => 'application/opensearchdescription+xml');
  xml;
  tag 'OpenSearchDescription',
    xmlns => 'http://a9.com/-/spec/opensearch/1.1/', 'xmlns:moz' => 'http://www.mozilla.org/2006/browser/search/';
   tag 'ShortName', 'VNDB';
   tag 'LongName', 'VNDB.org visual novel search';
   tag 'Description', 'Search visual vovels on VNDB.org';
   tag 'Image', width => 16, height => 16, type => 'image/x-icon', "$h/favicon.ico"
     if -s "$VNDB::ROOT/www/favicon.ico";
   tag 'Url', type => 'text/html', method => 'get', template => "$h/v/all?q={searchTerms}", undef;
   tag 'Url', type => 'application/opensearchdescription+xml', rel => 'self', template => "$h/opensearch.xml", undef;
   tag 'Query', role => 'example', searchTerms => 'Tsukihime', undef;
   tag 'moz:SearchForm', "$h/v/all";
  end 'OpenSearchDescription';
}


1;

