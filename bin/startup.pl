use strict;

use Apache2::RequestRec();
use Apache2::RequestIO();

use Apache::DBI;
use DBI;
use Amazon::S3;
use CGI;
use CGI::Cookie;
use Template;
use URI::Escape::JavaScript;
use Sort::Key;
use Data::Dumper::HTML;
use Crypt::ScryptKDF;
use String::CRC;
use UUID;
use JSON::XS;
use Text::Unaccent::PurePerl;
use Clone;
use HTML::Escape;
use Sort::Key::Multi;
use List::Slice;
use JavaScript::Minifier;
use Calendar::Simple;

use global::ttf;
use global::io;
use global::standard;
use global::charts;

use security::forms;

use security::login::auth;
use security::login::pre;
use security::login::post;

use security::inicio::auth;
use security::inicio::pre;
use security::inicio::post;

use security::configuracion::auth;
use security::configuracion::pre;
use security::configuracion::post;

use security::usuarios::auth;
use security::usuarios::pre;
use security::usuarios::post;

use security::clientes::auth;
use security::clientes::pre;
use security::clientes::post;

use security::membresias::auth;
use security::membresias::pre;
use security::membresias::post;

use security::descuentos::auth;
use security::descuentos::pre;
use security::descuentos::post;

use security::finanzas::auth;
use security::finanzas::pre;
use security::finanzas::post;

use security::asistencia::auth;
use security::asistencia::pre;
use security::asistencia::post;

use security::ventas::auth;
use security::ventas::pre;
use security::ventas::post;

use security::visitas::auth;
use security::visitas::pre;
use security::visitas::post;

use security::wods::auth;
use security::wods::pre;
use security::wods::post;

use security::buscar::auth;
use security::tips::auth;

use controller::clientes;
use controller::buscar;
use controller::login;
use controller::inicio;
use controller::configuracion;

use controller::asistencia;
use controller::asistencia::standard;

use controller::descuentos;
use controller::descuentos::management;

use controller::membresias;
use controller::membresias::groups;
use controller::membresias::management;

use controller::usuarios;
use controller::usuarios::management;

use controller::finanzas;
use controller::finanzas::charges;
use controller::finanzas::payments;

use controller::ventas;
use controller::ventas::standard;

use controller::tips::standard;
use controller::tips;

use controller::wods::standard;
use controller::wods;

use controller::visitas;

use model::base;
use model::attendance;
use model::init;
use model::users;
use model::clients;
use model::sessions;
use model::configuration;
use model::template_include;
use model::memberships;
use model::discounts;
use model::finance;
use model::charges;
use model::inventory;
use model::search;
use model::payments;
use model::transactions;
use model::visits;
use model::wods;

1;
