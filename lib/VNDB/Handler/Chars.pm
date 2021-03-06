
package VNDB::Handler::Chars;

use strict;
use warnings;
use TUWF ':html', 'uri_escape';
use Exporter 'import';
use VNDB::Func;
use List::Util 'min';

our @EXPORT = ('charOps', 'charTable', 'charBrowseTable');

TUWF::register(
  qr{c([1-9]\d*)(?:\.([1-9]\d*))?} => \&page,
  qr{c(?:([1-9]\d*)(?:\.([1-9]\d*))?/(edit|copy)|/new)}
    => \&edit,
  qr{c/([a-z0]|all)} => \&list,
);


sub page {
  my($self, $id, $rev) = @_;

  my $method = $rev ? 'dbCharGetRev' : 'dbCharGet';
  my $r = $self->$method(
    id => $id,
    what => 'extended traits vns seiyuu',
    $rev ? ( rev => $rev ) : ()
  )->[0];
  return $self->resNotFound if !$r->{id};

  my $metadata = {
    'og:title' => $r->{name},
    'og:description' => $r->{desc},
    'og:image' => $r->{image} && imgurl(ch => $r->{image}),
  };

  $self->htmlHeader(title => $r->{name}, noindex => $rev, metadata => $metadata);
  $self->htmlMainTabs(c => $r);
  return if $self->htmlHiddenMessage('c', $r);

  if($rev) {
    my $prev = $rev && $rev > 1 && $self->dbCharGetRev(id => $id, rev => $rev-1, what => 'extended traits vns')->[0];
    $self->htmlRevision('c', $prev, $r,
      [ name      => 'Name',          diff => 1 ],
      [ original  => 'Original name', diff => 1 ],
      [ alias     => 'Aliases',       diff => qr/[ ,\n\.]/ ],
      [ desc      => 'Description',   diff => qr/[ ,\n\.]/ ],
      [ gender    => 'Gender',        serialize => sub { $self->{genders}{$_[0]} } ],
      [ b_month   => 'Birthday/month',serialize => sub { $_[0]||'[empty]' } ],
      [ b_day     => 'Birthday/day',  serialize => sub { $_[0]||'[empty]' } ],
      [ s_bust    => 'Bust',          serialize => sub { $_[0]||'[empty]' } ],
      [ s_waist   => 'Waist',         serialize => sub { $_[0]||'[empty]' } ],
      [ s_hip     => 'Hip',           serialize => sub { $_[0]||'[empty]' } ],
      [ height    => 'Height',        serialize => sub { $_[0]||'[empty]' } ],
      [ weight    => 'Weight',        serialize => sub { $_[0]||'[empty]' } ],
      [ bloodt    => 'Blood type',    serialize => sub { $self->{blood_types}{$_[0]} } ],
      [ main      => 'Main character',htmlize => sub { $_[0] ? sprintf '<a href="/c%d">c%d</a>', $_[0], $_[0] : '[empty]' } ],
      [ main_spoil=> 'Spoiler',       serialize => \&fmtspoil ],
      [ image     => 'Image', htmlize => sub {
        return $_[0] ? sprintf '<img src="%s" />', imgurl(ch => $_[0]) : 'No image';
      }],
      [ traits    => 'Traits', join => '<br />', split => sub {
        map sprintf('%s<a href="/i%d">%s</a> (%s)', $_->{group}?qq|<b class="grayedout">$_->{groupname} / </b> |:'',
            $_->{tid}, $_->{name}, fmtspoil $_->{spoil}), @{$_[0]}
      }],
      [ vns       => 'Visual novels', join => '<br />', split => sub {
        map sprintf('<a href="/v%d">v%d</a> %s %s (%s)', $_->{vid}, $_->{vid},
          $_->{rid}?sprintf('[<a href="/r%d">r%d</a>]', $_->{rid}, $_->{rid}):'',
          $self->{char_roles}{$_->{role}}[0], fmtspoil $_->{spoil}), @{$_[0]};
      }],
    );
  }

  div class => 'mainbox';
   $self->htmlItemMessage('c', $r);
   $self->charOps(1);
   h1 $r->{name};
   h2 class => 'alttitle', $r->{original} if $r->{original};
   $self->charTable($r);
  end;

  # TODO: ordering of these instances?
  my $inst = [];
  if(!$r->{main}) {
    $inst = $self->dbCharGet(instance => $r->{id}, what => 'extended traits vns seiyuu');
  } else {
    $inst = $self->dbCharGet(instance => $r->{main}, notid => $r->{id}, what => 'extended traits vns seiyuu');
    push @$inst, $self->dbCharGet(id => $r->{main}, what => 'extended traits vns seiyuu')->[0];
  }
  if(@$inst) {
    my $spoil = sub { local $_=shift; !$r->{main} ? $_->{main_spoil} : $_->{main_spoil} > $r->{main_spoil} ? $_->{main_spoil} : $r->{main_spoil} };
    my $minspoil = min map $spoil->($_), @$inst;
    div class => 'mainbox '.charspoil($minspoil);
     h1 'Other instances';
     $self->charTable($_, 1, $_ != $inst->[0], 0, $spoil->($_)) for @$inst;
    end;
  }

  $self->htmlFooter;
}


sub charOps {
  my($self, $sexual) = @_;
  my $spoil = $self->authPref('spoilers')||0;
  p id => 'charops';
   # Note: Order of these links is hardcoded in JS
   a href => '#', $spoil == $_ ? (class => 'sel') : (), ['Hide spoilers', 'Show minor spoilers', 'Spoil me!']->[$_] for (0..2);
   a href => '#', class => 'sec'.($self->authPref('traits_sexual') ? ' sel' : ''), 'Show sexual traits' if $sexual;
  end;
}


# Also used from Handler::VNPage
sub charTable {
  my($self, $r, $link, $sep, $vn, $spoil) = @_;
  $spoil ||= 0;

  div class => 'chardetails '.charspoil($spoil).($sep ? ' charsep' : '');

   # image
   div class => 'charimg';
    if(!$r->{image}) {
      p 'No image uploaded yet';
    } else {
      img src => imgurl(ch => $r->{image}), alt => $r->{name};
    }
   end 'div';

   # info table
   table class => 'stripe';
    thead;
     Tr;
      td colspan => 2;
       if($link) {
         a href => "/c$r->{id}", style => 'margin-right: 10px; font-weight: bold', $r->{name};
       } else {
         b style => 'margin-right: 10px', $r->{name};
       }
       b class => 'grayedout', style => 'margin-right: 10px', $r->{original} if $r->{original};
       cssicon "gen $r->{gender}", $self->{genders}{$r->{gender}} if $r->{gender} ne 'unknown';
       span $self->{blood_types}{$r->{bloodt}} if $r->{bloodt} ne 'unknown';
      end;
     end;
    end;

    if($r->{alias}) {
      $r->{alias} =~ s/\n/, /g;
      Tr;
       td class => 'key', 'Aliases';
       td $r->{alias};
      end;
    }
    if($r->{height} || $r->{s_bust} || $r->{s_waist} || $r->{s_hip}) {
      Tr;
       td class => 'key', 'Measurements';
       td join ', ',
         $r->{height} ? "Height: $r->{height}cm" : (),
         $r->{weight} ? "Weight: $r->{weight}kg" : (),
         $r->{s_bust} || $r->{s_waist} || $r->{s_hip} ?
           sprintf 'Bust-Waist-Hips: %s-%s-%scm', $r->{s_bust}||'??', $r->{s_waist}||'??', $r->{s_hip}||'??' : ();
      end;
    }
    if($r->{b_month} && $r->{b_day}) {
      Tr;
       td class => 'key', 'Birthday';
       td $r->{b_day}.' '.[qw{January February March April May June July August September October November December}]->[$r->{b_month}-1];
      end;
    }

    # traits
    my %groups;
    my @groups;
    for (@{$r->{traits}}) {
      my $g = $_->{group}||$_->{tid};
      push @groups, $g if !$groups{$g};
      push @{$groups{ $g }}, $_
    }
    for my $g (@groups) {
      Tr class => 'traitrow';
       td class => 'key'; a href => '/i'.($groups{$g}[0]{group}||$groups{$g}[0]{tid}), $groups{$g}[0]{groupname} || $groups{$g}[0]{name}; end;
       td;
        for (0..$#{$groups{$g}}) {
          my $t = $groups{$g}[$_];
          span class => charspoil($t->{spoil}).($t->{sexual} ? ' sexual hidden' : '');
           span ', ';
           a href => "/i$t->{tid}", $t->{name};
          end;
        }
       end;
      end;
    }

    # vns
    if(@{$r->{vns}} && (!$vn || $vn && (@{$r->{vns}} > 1 || $r->{vns}[0]{rid}))) {
      my %vns;
      push @{$vns{$_->{vid}}}, $_ for(sort { !defined($a->{rid})?1:!defined($b->{rid})?-1:$a->{rtitle} cmp $b->{rtitle} } @{$r->{vns}});
      Tr;
       td class => 'key', $vn ? 'Releases' : 'Visual novels';
       td;
        my $first = 0;
        for my $g (sort { $vns{$a}[0]{vntitle} cmp $vns{$b}[0]{vntitle} } keys %vns) {
          br if $first++;
          my @r = @{$vns{$g}};
          # special case: all releases, no exceptions
          if(!$vn && @r == 1 && !$r[0]{rid}) {
            span class => charspoil $r[0]{spoil};
             txt $self->{char_roles}{$r[0]{role}}[0].' - ';
             a href => "/v$r[0]{vid}/chars", $r[0]{vntitle};
            end;
            next;
          }
          # otherwise, print VN title and list releases separately
          my $minspoil = 5;
          $minspoil = $minspoil > $_->{spoil} ? $_->{spoil} : $minspoil for (@r);
          span class => charspoil $minspoil;
           a href => "/v$r[0]{vid}/chars", $r[0]{vntitle} if !$vn;
           for(@r) {
             span class => charspoil $_->{spoil};
              br if !$vn || $_ != $r[0];
              b class => 'grayedout', '> ';
              txt $self->{char_roles}{$_->{role}}[0].' - ';
              if($_->{rid}) {
                b class => 'grayedout', "r$_->{rid}:";
                a href => "/r$_->{rid}", $_->{rtitle};
              } else {
                txt 'All other releases';
              }
             end;
           }
          end;
        }
       end;
      end;
    }

    if(@{$r->{seiyuu}}) {
      Tr;
       td class => 'key', 'Voiced by';
       td;
        my $last_name = '';
        for my $s (sort { $a->{name} cmp $b->{name} } @{$r->{seiyuu}}) {
          next if $s->{name} eq $last_name;
          a href => "/s$s->{sid}", title => $s->{original}||$s->{name}, $s->{name};
          txt ' ('.$s->{note}.')' if $s->{note};
          br;
          $last_name = $s->{name};
        }
       end;
      end;
    }

    # description
    if($r->{desc}) {
      Tr class => 'nostripe';
       td class => 'chardesc', colspan => 2;
        h2 'Description';
        p;
         lit bb2html $r->{desc}, 0, 1;
        end;
       end;
      end;
    }

   end 'table';
  end;
  clearfloat;
}



sub edit {
  my($self, $id, $rev, $copy) = @_;

  $copy = $rev && $rev eq 'copy' || $copy && $copy eq 'copy';
  $rev = undef if defined $rev && $rev !~ /^\d+$/;

  my $r = $id && $self->dbCharGetRev(id => $id, what => 'extended vns traits', $rev ? (rev => $rev) : ())->[0];
  return $self->resNotFound if $id && !$r->{id};
  $rev = undef if !$r || $r->{lastrev};

  return $self->htmlDenied if !$self->authCan('edit')
    || $id && (($r->{locked} || $r->{hidden}) && !$self->authCan('dbmod'));

  my %b4 = !$id ? () : (
    (map +($_ => $r->{$_}), qw|name original alias desc image ihid ilock s_bust s_waist s_hip height weight bloodt gender main_spoil|),
    main => $r->{main}||0,
    bday => $r->{b_month} ? sprintf('%02d-%02d', $r->{b_month}, $r->{b_day}) : '',
    traits => join(' ', map sprintf('%d-%d', $_->{tid}, $_->{spoil}), sort { $a->{tid} <=> $b->{tid} } @{$r->{traits}}),
    vns => join(' ', map sprintf('%d-%d-%d-%s', $_->{vid}, $_->{rid}||0, $_->{spoil}, $_->{role}),
      sort { $a->{vid} <=> $b->{vid} || ($a->{rid}||0) <=> ($b->{rid}||0) } @{$r->{vns}}),
  );
  my $frm;

  if($self->reqMethod eq 'POST') {
    return if !$self->authCheckCode;
    $frm = $self->formValidate(
      { post => 'name',          maxlength => 200 },
      { post => 'original',      required  => 0, maxlength => 200,  default => '' },
      { post => 'alias',         required  => 0, maxlength => 500,  default => '' },
      { post => 'desc',          required  => 0, maxlength => 5000, default => '' },
      { post => 'gender',        required  => 0, default => 'unknown', enum => [ keys %{$self->{genders}} ] },
      { post => 'image',         required  => 0, default => 0,  template => 'id' },
      { post => 'bday',          required  => 0, default => '', regex => [ qr/^(?:[01]?[0-9])-(?:[0123]?[0-9])$/, 'Birthday must be in MM-DD format.' ] },
      { post => 's_bust',        required  => 0, default => 0, template => 'uint', max => 32767 },
      { post => 's_waist',       required  => 0, default => 0, template => 'uint', max => 32767 },
      { post => 's_hip',         required  => 0, default => 0, template => 'uint', max => 32767 },
      { post => 'height',        required  => 0, default => 0, template => 'uint', max => 32767 },
      { post => 'weight',        required  => 0, default => 0, template => 'uint', max => 32767 },
      { post => 'bloodt',        required  => 0, default => 'unknown', enum => [ keys %{$self->{blood_types}} ] },
      { post => 'main',          required  => 0, default => 0, template => 'id' },
      { post => 'main_spoil',    required  => 0, default => 0, enum => [ 0..2 ] },
      { post => 'traits',        required  => 0, default => '', regex => [ qr/^(?:[1-9]\d*-[0-2])(?: +[1-9]\d*-[0-2])*$/, 'Incorrect trait format.' ] },
      { post => 'vns',           required  => 0, default => '', regex => [ qr/^(?:[1-9]\d*-\d+-[0-2]-[a-z]+)(?: +[1-9]\d*-\d+-[0-2]-[a-z]+)*$/, 'Incorrect VN format.' ] },
      { post => 'editsum',       template => 'editsum' },
      { post => 'ihid',          required  => 0 },
      { post => 'ilock',         required  => 0 },
    );

    # handle image upload
    $frm->{image} = _uploadimage($self, $frm);

    # validate main character
    if(!$frm->{_err} && $frm->{main}) {
      my $m = $self->dbCharGet(id => $frm->{main}, what => 'extended')->[0];
      push @{$frm->{_err}}, 'Invalid main character. Make sure the ID is correct,'
          .' that the main character itself is not an instance of an other character,'
          .' and that this entry is not used as a main character elsewhere.'
        if !$m || $m->{main} || $r && !$copy && ($m->{id} == $r->{id} || $self->dbCharGet(instance => $r->{id})->[0]);
    }

    my(@traits, @vns);
    if(!$frm->{_err}) {
      # parse and normalize
      @traits = sort { $a->[0] <=> $b->[0] } map /^(\d+)-(\d+)$/&&[$1,$2], split / /, $frm->{traits};
      @vns = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] }  map [split /-/], split / /, $frm->{vns};
      $frm->{traits} = join(' ', map sprintf('%d-%d', @$_), @traits);
      $frm->{vns}    = join(' ', map sprintf('%d-%d-%d-%s', @$_), @vns);
      $frm->{ihid}   = $frm->{ihid} ?1:0;
      $frm->{ilock}  = $frm->{ilock}?1:0;
      $frm->{desc}   = $self->bbSubstLinks($frm->{desc});
      $frm->{main_spoil} = 0 if !$frm->{main};

      my %traits = @traits ? map +($_->{id}, 1), @{$self->dbTraitGet(results => 500, state => 2, id => [ map $_->[0], @traits ])} : ();
      @traits = grep $traits{$_->[0]}, @traits;

      # check for changes
      my $same = $id && !grep $frm->{$_} ne $b4{$_}, keys %b4;
      return $self->resRedirect("/c$id", 'post') if !$copy && $same;
      $frm->{_err} = ["No changes, please don't create an entry that is fully identical to another"] if $copy && $same;
    }

    if(!$frm->{_err}) {
      # modify for dbCharRevisionInsert
      ($frm->{b_month}, $frm->{b_day}) = delete($frm->{bday}) =~ /^(\d{2})-(\d{2})$/ ? ($1, $2) : (0, 0);
      $frm->{main} ||= undef;
      $frm->{traits} = \@traits;
      $_->[1]||=undef for (@vns);
      $frm->{vns} = \@vns;

      my $nrev = $self->dbItemEdit(c => !$copy && $id ? ($r->{id}, $r->{rev}) : (undef, undef), %$frm);
      return $self->resRedirect("/c$nrev->{itemid}.$nrev->{rev}", 'post');
    }
  }

  if(!$id) {
    my $vid = $self->formValidate({ get => 'vid', required => 1, template => 'id'});
    $frm->{vns} //= "$vid->{vid}-0-0-primary" if !$vid->{_err};
  }
  $frm->{$_} //= $b4{$_} for keys %b4;
  $frm->{editsum} //= sprintf 'Reverted to revision c%d.%d', $id, $rev if !$copy && $rev;
  $frm->{editsum} = sprintf 'New character based on c%d.%d', $id, $r->{rev} if $copy;

  my $title = !$r ? 'Add new character' : $copy ? "Copy $r->{name}" : "Edit $r->{name}";
  $self->htmlHeader(title => $title, noindex => 1);
  $self->htmlMainTabs('c', $r, $copy ? 'copy' : 'edit') if $r;
  $self->htmlEditMessage('c', $r, $title, $copy);
  $self->htmlForm({ frm => $frm, action => $r ? "/c$id/".($copy ? 'copy' : 'edit') : '/c/new', editsum => 1, upload => 1 },
  chare_geninfo => [ 'General info',
    [ input  => name => 'Name (romaji)', short => 'name' ],
    [ input  => name => 'Original name', short => 'original' ],
    [ static => content => 'The original name of the character, leave blank if it is already in the Latin alphabet.' ],
    [ text   => name => 'Aliases', short => 'alias', rows => 3 ],
    [ static => content => '(Un)official aliases, separated by a newline.' ],
    [ text   => name => 'Description<br /><b class="standout">English please!</b>', short => 'desc', rows => 6 ],
    [ select => name => 'Gender',short => 'gender', options => [
       map [ $_, $self->{genders}{$_} ], keys %{$self->{genders}} ] ],
    [ input  => name => 'Birthday',  short => 'bday',   width => 100,post => ' MM-DD (e.g. "01-26" for the 26th of January)'  ],
    [ input  => name => 'Bust',      short => 's_bust', width => 50, post => ' cm' ],
    [ input  => name => 'Waist',     short => 's_waist',width => 50, post => ' cm' ],
    [ input  => name => 'Hips',      short => 's_hip',  width => 50, post => ' cm' ],
    [ input  => name => 'Height',    short => 'height', width => 50, post => ' cm' ],
    [ input  => name => 'Weight',    short => 'weight', width => 50, post => ' kg' ],
    [ select => name => 'Blood type',short => 'bloodt', options => [
       map [ $_, $self->{blood_types}{$_} ], keys %{$self->{blood_types}} ] ],
    [ static => content => '<br />' ],
    [ input  => name => 'Instance of',short => 'main', width => 50, post => ' ID of the main character - the character of which this is an instance of.' ],
    [ select => name => 'Spoiler',  short => 'main_spoil', options => [
       map [$_, fmtspoil $_], 0..2 ] ],
  ],

  chare_img => [ 'Image', [ static => nolabel => 1, content => sub {
    div class => 'img';
     p 'No image uploaded yet' if !$frm->{image};
     img src => imgurl(ch => $frm->{image}) if $frm->{image};
    end;

    div;
     h2 'Image ID';
     input type => 'text', class => 'text', name => 'image', id => 'image', value => $frm->{image}||'';
     p 'Use a character image that is already on the server. Set to \'0\' to remove the current image.';
     br; br;

     h2 'Upload new image';
     input type => 'file', class => 'text', name => 'img', id => 'img';
     p 'Image must be in JPEG or PNG format and at most 1MiB. Images larger than 256x300 will automatically be resized. Image must be safe for work!';
    end;
  }]],

  chare_traits => [ 'Traits',
    [ hidden => short => 'traits' ],
    [ static => nolabel => 1, content => sub {
      h2 'Current traits';
      table; tbody id => 'traits_tbl';
       Tr id => 'traits_loading'; td colspan => '3', 'Loading...'; end;
      end; end;
      h2 'Add trait';
      table; Tr;
       td class => 'tc_name'; input id => 'trait_input', type => 'text', class => 'text'; end;
       td colspan => 2, '';
      end; end 'table';
    }],
  ],

  chare_vns => [ 'Visual novels',
    [ hidden => short => 'vns' ],
    [ static => nolabel => 1, content => sub {
      h2 'Selected visual novels';
      table; tbody id => 'vns_tbl';
       Tr id => 'vns_loading'; td colspan => '4', 'Loading...'; end;
      end; end;
      h2 'Add visual novel';
      table; Tr;
       td class => 'tc_vnadd'; input id => 'vns_input', type => 'text', class => 'text'; end;
       td colspan => 3, '';
      end; end;
    }],
  ]);
  $self->htmlFooter;
}


sub _uploadimage {
  my($self, $frm) = @_;

  if($frm->{_err} || !$self->reqPost('img')) {
    return 0 if !$frm->{image};
    push @{$frm->{_err}}, 'No image with that ID' if !-s imgpath(ch => $frm->{image});
    return $frm->{image};
  }

  # perform some elementary checks
  my $imgdata = $self->reqUploadRaw('img');
  $frm->{_err} = [ 'Image must be in JPEG or PNG format' ] if $imgdata !~ /^(\xff\xd8|\x89\x50)/; # JPG or PNG headers
  $frm->{_err} = [ 'Image is too large, only 1MB allowed' ] if length($imgdata) > 1024*1024;
  return undef if $frm->{_err};

  # resize/compress
  my $im = Image::Magick->new;
  $im->BlobToImage($imgdata);
  my($ow, $oh) = ($im->Get('width'), $im->Get('height'));
  my($nw, $nh) = imgsize($ow, $oh, @{$self->{ch_size}});
  $im->Set(background => '#ffffff');
  $im->Set(alpha => 'Remove');
  if($ow != $nw || $oh != $nh) {
    $im->GaussianBlur(geometry => '0.5x0.5');
    $im->Resize(width => $nw, height => $nh);
    $im->UnsharpMask(radius => 0, sigma => 0.75, amount => 0.75, threshold => 0.008);
  }
  $im->Set(magick => 'JPEG', quality => 90);

  # Get ID and save
  my $imgid = $self->dbCharImageId;
  my $fn = imgpath(ch => $imgid);
  $im->Write($fn);
  chmod 0666, $fn;

  return $imgid;
}


sub list {
  my($self, $fch) = @_;

  my $f = $self->formValidate(
    { get => 'p',   required => 0, default => 1, template => 'page' },
    { get => 'q',   required => 0, default => '' },
    { get => 'fil', required => 0, default => '' },
  );
  return $self->resNotFound if $f->{_err};

  my($list, $np) = $self->filFetchDB(char => $f->{fil}, {
    tagspoil => $self->authPref('spoilers')||0,
  }, {
    $fch ne 'all' ? ( char => $fch ) : (),
    $f->{q} ? ( search => $f->{q} ) : (),
    results => 50,
    page => $f->{p},
    what => 'vns',
  });

  $self->htmlHeader(title => 'Browse characters');

  my $quri = uri_escape($f->{q});
  form action => '/c/all', 'accept-charset' => 'UTF-8', method => 'get';
  div class => 'mainbox';
   h1 'Browse characters';
   $self->htmlSearchBox('c', $f->{q});
   p class => 'browseopts';
    for ('all', 'a'..'z', 0) {
      a href => "/c/$_?q=$quri", $_ eq $fch ? (class => 'optselected') : (), $_ eq 'all' ? 'ALL' : $_ ? uc $_ : '#';
    }
   end;

   p class => 'filselect';
    a id => 'filselect', href => '#c';
     lit '<i>&#9656;</i> Filters<i></i>';
    end;
   end;
   input type => 'hidden', class => 'hidden', name => 'fil', id => 'fil', value => $f->{fil};
  end;
  end 'form';

  if(!@$list) {
    div class => 'mainbox';
     h1 'No results';
     p 'No characters found that matched your criteria.';
    end;
  }

  @$list && $self->charBrowseTable($list, $np, $f, "/c/$fch?q=$quri;fil=$f->{fil}");

  $self->htmlFooter;
}


# Also used on Handler::Traits
sub charBrowseTable {
  my($self, $list, $np, $f, $uri) = @_;

  $self->htmlBrowse(
    class    => 'charb',
    items    => $list,
    options  => $f,
    nextpage => $np,
    pageurl  => $uri,
    sorturl  => $uri,
    header   => [ [ '' ], [ '' ] ],
    row      => sub {
      my($s, $n, $l) = @_;
      Tr;
       td class => 'tc1';
        cssicon "gen $l->{gender}", $self->{genders}{$l->{gender}} if $l->{gender} ne 'unknown';
       end;
       td class => 'tc2';
        a href => "/c$l->{id}", title => $l->{original}||$l->{name}, shorten $l->{name}, 50;
        b class => 'grayedout';
         my $i = 1;
         my %vns;
         for (@{$l->{vns}}) {
           next if $_->{spoil} || $vns{$_->{vid}}++;
           last if $i++ > 4;
           txt ', ' if $i > 2;
           a href => "/v$_->{vid}/chars", title => $_->{vntitle}, shorten $_->{vntitle}, 30;
         }
        end;
       end;
      end;
    }
  )
}


1;

